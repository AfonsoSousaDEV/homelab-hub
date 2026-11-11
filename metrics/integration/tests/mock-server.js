'use strict';
// Local substitutes only. The test network is internal and exposes no host ports.
const http = require('node:http');
const counts = {};
http.createServer(async (req, res) => {
  if (req.url === '/health') { res.end('ok'); return; }
  if (req.url === '/counts') { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(counts)); return; }
  const [service, scenario] = req.url.split('/').filter(Boolean);
  counts[scenario] ||= { ollama: 0, discord: 0 };
  counts[scenario][service] += 1;
  let raw = '';
  for await (const chunk of req) raw += chunk;
  let body;
  try { body = JSON.parse(raw); } catch { res.statusCode = 400; res.end('Expected JSON'); return; }
  if (service === 'discord') {
    if (typeof body.content !== 'string' || !body.content || body.content.length > 2000
      || !Array.isArray(body.allowed_mentions?.parse) || body.allowed_mentions.parse.length) {
      res.statusCode = 400; res.end('Invalid message or unsafe mention parsing'); return;
    }
    res.statusCode = scenario === 'discord-failure'
      || (scenario === 'discord-partial' && counts[scenario].discord === 2) ? 503 : 204;
    res.end(); return;
  }
  if (scenario === 'unavailable') { res.statusCode = 503; res.end('Synthetic provider outage'); return; }
  if (scenario === 'timeout') await new Promise(resolve => setTimeout(resolve, 1500));
  const summaries = [1, 2].map(index => ({ index, priority: 'high', summary: `Synthetic summary ${index}`, action: '' }));
  if (scenario === 'duplicate') summaries[1].index = 1;
  if (scenario === 'bad-priority') summaries[0].priority = 'constructor';
  if (scenario === 'multipart' || scenario === 'discord-partial') {
    summaries.forEach(row => { row.summary = 'Synthetic long summary '.repeat(65); });
  }
  const output = { overview: 'Synthetic inbox', emails: scenario === 'missing' ? [] : summaries };
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ message: { content: scenario === 'invalid' ? 'not JSON' : JSON.stringify(output) } }));
}).listen(8080, '0.0.0.0');
