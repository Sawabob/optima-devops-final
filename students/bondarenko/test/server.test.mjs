import assert from 'node:assert/strict';
import { once } from 'node:events';
import { after, before, test } from 'node:test';
import { createStudyServer } from '../src/server.mjs';

const server = createStudyServer();
let base;

before(async () => {
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve())));

test('serves the planner and the JavaScript it needs', async () => {
  const page = await fetch(`${base}/`);
  assert.equal(page.status, 200);
  assert.match(await page.text(), /Навчальні дедлайни/);
  const script = await fetch(`${base}/app.js`);
  assert.match(script.headers.get('content-type'), /javascript/);
  assert.match(await script.text(), /localStorage/);
});

test('provides a health endpoint for GET and HEAD', async () => {
  const health = await fetch(`${base}/healthz`);
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: 'ok' });
  const head = await fetch(`${base}/healthz`, { method: 'HEAD' });
  assert.equal(head.status, 200);
  assert.equal(await head.text(), '');
});

test('returns 404 for missing assets and rejects unsupported methods', async () => {
  assert.equal((await fetch(`${base}/missing`)).status, 404);
  const post = await fetch(`${base}/`, { method: 'POST' });
  assert.equal(post.status, 405);
  assert.equal(post.headers.get('allow'), 'GET, HEAD');
});
