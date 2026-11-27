import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';

const assets = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/styles.css', ['styles.css', 'text/css; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']],
]);

export function createStudyServer() {
  return createServer(async (request, response) => {
    response.setHeader('Content-Security-Policy', "default-src 'self'; base-uri 'none'; frame-ancestors 'none'");
    response.setHeader('X-Content-Type-Options', 'nosniff');
    const reply = (status, type, body) => {
      response.writeHead(status, { 'Content-Type': type });
      response.end(request.method === 'HEAD' ? undefined : body);
    };

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      response.setHeader('Allow', 'GET, HEAD');
      reply(405, 'text/plain; charset=utf-8', 'Method not allowed');
      return;
    }

    const path = request.url.split('?', 1)[0];
    if (path === '/healthz') {
      reply(200, 'application/json; charset=utf-8', JSON.stringify({ status: 'ok' }));
      return;
    }

    const asset = assets.get(path);
    if (!asset) {
      reply(404, 'text/plain; charset=utf-8', 'Not found');
      return;
    }

    try {
      const [file, type] = asset;
      const content = await readFile(new URL(`./public/${file}`, import.meta.url));
      reply(200, type, content);
    } catch (error) {
      console.error('Cannot read application asset:', error.message);
      reply(500, 'text/plain; charset=utf-8', 'Internal server error');
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const port = Number(process.env.PORT || 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer from 1 to 65535.');
  }
  const server = createStudyServer();
  server.listen(port, '0.0.0.0', () => console.log(`Study board listening on ${port}`));
  process.once('SIGTERM', () => server.close());
  process.once('SIGINT', () => server.close());
}
