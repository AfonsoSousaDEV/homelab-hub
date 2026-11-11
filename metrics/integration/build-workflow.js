'use strict';

const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const upstream = JSON.parse(fs.readFileSync(path.join(root, 'upstream/EmailDigest00001.json'), 'utf8'));
const helpers = fs.readFileSync(path.join(root, 'digest-logic.js'), 'utf8').replace(/^module\.exports = .*;\s*$/m, '');
const nodes = [];
const connections = {};
const original = name => structuredClone(upstream.nodes.find(node => node.name === name));
function add(node, x, y) { node.position = [x, y]; nodes.push(node); return node; }
function node(name, type, parameters, version = 1) {
  return { id: 'metrics-' + name.toLowerCase().replace(/[^a-z0-9]+/g, '-'), name,
    type: 'n8n-nodes-base.' + type, typeVersion: version, parameters };
}
function code(name, source) { return node(name, 'code', { jsCode: helpers + '\n' + source }, 2); }
function pg(name, query, parameters) {
  return node(name, 'postgres', { operation: 'executeQuery', query,
    options: { queryReplacement: parameters } }, 2.6);
}
function condition(name, expression) {
  return node(name, 'if', { conditions: { options: { caseSensitive: true,
    typeValidation: 'strict', version: 2 }, combinator: 'and', conditions: [{
      id: name, leftValue: expression, rightValue: true,
      operator: { type: 'boolean', operation: 'true', singleValue: true },
    }] }, options: {} }, 2.2);
}
function connect(from, to, output = 0) {
  connections[from] ||= { main: [] };
  while (connections[from].main.length <= output) connections[from].main.push([]);
  connections[from].main[output].push({ node: to, type: 'main', index: 0 });
}
const returned = 'id AS run_id, workflow_key, execution_key, model_name, emails_total, emails_summarized, emails_failed';
add(original('Every day at 08:00'), 0, 0);
add(original('Run manually (testing)'), 0, 200);
add(node('Run context', 'set', { assignments: { assignments: [
  { id: 'workflow', name: 'workflow_key', type: 'string', value: 'email-digest' },
  { id: 'execution', name: 'execution_key', type: 'string', value: '={{ String($execution.id) }}' },
  { id: 'model', name: 'model_name', type: 'string', value: "={{ $env.OLLAMA_MODEL || 'qwen3:4b' }}" },
] }, options: {} }, 3.4), 220, 100);
add(pg('Start metrics run', `WITH created AS (
INSERT INTO metrics.workflow_runs (workflow_key, execution_key, model_name)
VALUES ($1, $2, $3) ON CONFLICT (workflow_key, execution_key) DO NOTHING RETURNING ${returned}
)
SELECT created.*, true AS acquired FROM created
UNION ALL
SELECT NULL::uuid, $1::text, $2::text, $3::text, 0, 0, 0, false
WHERE NOT EXISTS (SELECT 1 FROM created);`,
  '={{ [$json.workflow_key, $json.execution_key, $json.model_name] }}'), 440, 100);
add(condition('New attempt acquired?', '={{ $json.acquired }}'), 660, 100);
const gmail = original('Get unread emails'); gmail.onError = 'continueRegularOutput';
add(gmail, 660, 100);
add(code('Prepare emails', "return [{json: prepareEmails($input.all().map(item => item.json), $('Start metrics run').first().json)}];"), 880, 100);
add(condition('Has emails to summarize?', '={{ $json.needs_summary }}'), 1100, 100);
add(pg('Record selected count', `UPDATE metrics.workflow_runs SET emails_total = $2
WHERE id = $1::uuid AND status = 'running' RETURNING ${returned};`,
  '={{ [$json.run_id, $json.emails_total] }}'), 1320, 0);
const ollama = original('Ask Ollama'); ollama.onError = 'continueRegularOutput';
ollama.parameters.jsonBody = "={{ JSON.stringify($('Prepare emails').first().json.ollamaRequest) }}";
add(ollama, 1540, 0);
add(code('Validate and format', "return [{json: validateAndFormat($input.first().json, $('Prepare emails').first().json)}];"), 1760, 0);
add(condition('Has valid summaries?', '={{ $json.needs_delivery }}'), 1980, 0);
add(pg('Record summarized count', `UPDATE metrics.workflow_runs SET emails_summarized = $2
WHERE id = $1::uuid AND status = 'running' RETURNING ${returned};`,
  '={{ [$json.run_id, $json.emails_summarized] }}'), 2200, -100);
add(code('Prepare Discord posts', "return $('Validate and format').first().json.messages.map(content => ({json: {content}}));"), 2420, -100);
const discord = original('Post to Discord');
discord.onError = 'continueRegularOutput'; discord.alwaysOutputData = true;
discord.parameters.jsonBody = '={{ JSON.stringify({ content: $json.content, allowed_mentions: { parse: [] } }) }}';
discord.parameters.options = { timeout: 15000,
  response: { response: { fullResponse: true, responseFormat: 'text' } } };
add(discord, 2640, -100);
add(code('Collect delivery result', "return [{json: deliveryResult($input.all().map(item => item.json), $('Validate and format').first().json)}];"), 2860, -100);
add(pg('Complete metrics run', `UPDATE metrics.workflow_runs
SET status = $2, finished_at = clock_timestamp(), emails_total = $3,
    emails_summarized = $4, emails_failed = $5, error_code = $6
WHERE id = $1::uuid AND status = 'running'
RETURNING ${returned}, status, error_code;`,
  '={{ [$json.run_id, $json.status, $json.emails_total, $json.emails_summarized, $json.emails_failed, $json.error_code] }}'), 3080, 250);
add(condition('Run failed?', "={{ $json.status === 'failed' }}"), 3300, 250);
add(node('Report sanitized failure', 'stopAndError', { errorType: 'errorMessage',
  errorMessage: '={{ $json.error_code }}' }), 3520, 150);
connect('Every day at 08:00', 'Run context');
connect('Run manually (testing)', 'Run context');
for (const [from, to] of [
  ['Run context', 'Start metrics run'], ['Start metrics run', 'New attempt acquired?'],
  ['New attempt acquired?', 'Get unread emails'],
  ['Get unread emails', 'Prepare emails'], ['Prepare emails', 'Has emails to summarize?'],
  ['Has emails to summarize?', 'Record selected count'], ['Record selected count', 'Ask Ollama'],
  ['Ask Ollama', 'Validate and format'], ['Validate and format', 'Has valid summaries?'],
  ['Has valid summaries?', 'Record summarized count'], ['Record summarized count', 'Prepare Discord posts'],
  ['Prepare Discord posts', 'Post to Discord'], ['Post to Discord', 'Collect delivery result'],
  ['Collect delivery result', 'Complete metrics run'], ['Complete metrics run', 'Run failed?'],
  ['Run failed?', 'Report sanitized failure'],
]) connect(from, to);
connect('Has emails to summarize?', 'Complete metrics run', 1);
connect('Has valid summaries?', 'Complete metrics run', 1);
// Make room for the acquisition gate without overlapping the original Gmail node.
for (const item of nodes) {
  if (item.name !== 'New attempt acquired?' && item.position[0] >= 660) item.position[0] += 220;
}
const output = { id: 'EmailDigestMetrics00001', name: 'Email digest → Discord (metrics)',
  active: false, nodes, connections, settings: structuredClone(upstream.settings), pinData: {}, tags: [] };
const directory = path.join(root, 'workflows');
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(path.join(directory, 'EmailDigestMetrics00001.json'), JSON.stringify(output, null, 2) + '\n');
console.log('Generated inactive metrics workflow:', nodes.length, 'nodes');
