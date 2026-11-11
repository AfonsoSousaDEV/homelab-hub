'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { prepareEmails, validateAndFormat, deliveryResult, splitMessage } = require('../digest-logic');
const run = { run_id: 'test-uuid', workflow_key: 'test', execution_key: '1', model_name: 'synthetic-model' };
const emails = [1, 2].map(i => ({ id: `synthetic-${i}`, from: { text: 'Test <test@example.invalid>' },
  subject: `Subject ${i}`, text: 'Synthetic email body' }));
const prepared = () => prepareEmails(emails, run);
const response = rows => ({ message: { content: JSON.stringify({ overview: 'Synthetic overview', emails: rows }) } });
const summaries = () => [1, 2].map(index => ({ index, priority: 'high', summary: `Summary ${index}`, action: '' }));

test('empty inbox still produces one successful terminal result', () => {
  const result = prepareEmails([{}], run);
  assert.equal(result.status, 'succeeded');
  assert.equal(result.emails_total, 0);
  assert.equal(result.needs_summary, false);
});
test('Gmail failure is metadata only', () => {
  const result = prepareEmails([{ error: 'secret raw exception' }], run);
  assert.equal(result.error_code, 'GMAIL_READ_FAILED');
  assert.ok(!JSON.stringify(result).includes('secret raw exception'));
});
test('parsed Gmail shape and bounded model input', () => {
  const result = prepareEmails([{ ...emails[0], text: 'x'.repeat(5000) }], run);
  assert.equal(result.emails[0].from, 'Test');
  assert.equal(result.emails[0].body.length, 1500);
  assert.equal(result.ollamaRequest.model, 'synthetic-model');
});
test('malformed, missing, duplicate, unknown and incomplete summaries fail before delivery', () => {
  const duplicate = summaries(); duplicate[1].index = 1;
  const badPriority = summaries(); badPriority[0].priority = 'constructor';
  const badSummary = summaries(); badSummary[0].summary = '';
  for (const item of [{ message: { content: 'not JSON' } }, response([]), response([summaries()[0]]),
    response(duplicate), response(badPriority), response(badSummary), {}]) {
    const result = validateAndFormat(item, prepared());
    assert.equal(result.error_code, 'INVALID_MODEL_RESPONSE');
    assert.equal(result.emails_summarized, 0);
    assert.equal(result.emails_failed, 2);
    assert.equal(result.needs_delivery, false);
    assert.equal(result.messages, undefined);
  }
});
test('provider errors distinguish timeout and unavailable', () => {
  assert.equal(validateAndFormat({ error: { code: 'ETIMEDOUT' } }, prepared()).error_code, 'OLLAMA_TIMEOUT');
  assert.equal(validateAndFormat({ error: '503 unavailable' }, prepared()).error_code, 'OLLAMA_UNAVAILABLE');
});
test('all chunks must succeed before one successful completion', () => {
  const rows = summaries(); rows.forEach(row => { row.summary = 'Long summary '.repeat(140); });
  const valid = validateAndFormat(response(rows), prepared());
  assert.ok(valid.messages.length > 1);
  assert.ok(valid.messages.every(text => text.length <= 1900));
  const deliveries = valid.messages.map(() => ({ statusCode: 204 }));
  assert.equal(deliveryResult(deliveries, valid).status, 'succeeded');
  deliveries[1] = { error: 'secret webhook error' };
  const failed = deliveryResult(deliveries, valid);
  assert.equal(failed.error_code, 'DISCORD_SEND_FAILED');
  assert.equal(failed.emails_summarized, 2);
  assert.equal(failed.emails_failed, 0);
  assert.ok(!JSON.stringify(failed).includes('secret webhook error'));
  assert.equal(deliveryResult([], valid).status, 'failed');
});
test('chunking preserves all text and Unicode pairs', () => {
  const text = ('x'.repeat(1899) + '😀\n').repeat(3);
  const chunks = splitMessage(text);
  assert.equal(chunks.join(''), text);
  assert.ok(chunks.every(chunk => chunk.length <= 1900));
  assert.ok(chunks.every(chunk => !/[\uD800-\uDBFF]$/.test(chunk)));
});
