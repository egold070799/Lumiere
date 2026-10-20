const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');

const FIXED_HOSTS = new Set([
  'www.youtube.com',
  'music.youtube.com',
  'youtubei.googleapis.com',
]);

function isAllowedTarget(url) {
  if (url.protocol !== 'https:' || url.port || url.username || url.password) {
    return false;
  }
  const host = url.hostname.toLowerCase();
  if (FIXED_HOSTS.has(host)) {
    return (
      url.pathname.startsWith('/youtubei/v1/') ||
      url.pathname === '/playlist' ||
      url.pathname === '/watch' ||
      url.pathname === '/results' ||
      url.pathname === '/sw.js_data' ||
      url.pathname === '/api/timedtext' ||
      /^\/(channel|user|c|@)[^/]+/.test(url.pathname)
    );
  }
  return host.endsWith('.googlevideo.com') && url.pathname === '/videoplayback';
}

function localProxyUrl(target) {
  if (!isAllowedTarget(target)) return null;
  return `/api/youtube/${target.hostname}${target.pathname}${target.search}`;
}

function copyResponseHeaders(upstream, response) {
  for (const name of [
    'accept-ranges',
    'cache-control',
    'content-length',
    'content-range',
    'content-type',
    'etag',
    'last-modified',
  ]) {
    const value = upstream.headers.get(name);
    if (value) response.setHeader(name, value);
  }

  const location = upstream.headers.get('location');
  if (location) {
    try {
      const target = new URL(location, upstream.url);
      const proxied = localProxyUrl(target);
      response.setHeader('location', proxied || location);
    } catch {
      response.setHeader('location', location);
    }
  }
}

module.exports = async function youtubeProxy(req, res) {
  const routeTarget = req.query.target;
  const targetParts = Array.isArray(routeTarget)
    ? routeTarget
    : typeof routeTarget === 'string'
      ? routeTarget.split('/')
      : [];
  if (targetParts.length < 2) {
    res.status(400).send('Invalid YouTube proxy path');
    return;
  }

  const [host, ...pathParts] = targetParts;
  let target;
  try {
    target = new URL(`https://${host}/${pathParts.join('/')}`);
    target.search = req.url.includes('?') ? req.url.slice(req.url.indexOf('?')) : '';
  } catch {
    res.status(400).send('Invalid YouTube proxy target');
    return;
  }

  if (!isAllowedTarget(target)) {
    res.status(403).send('YouTube proxy target is not allowed');
    return;
  }

  const headers = new Headers();
  for (const name of [
    'accept',
    'content-type',
    'range',
    'if-range',
    'if-none-match',
    'if-modified-since',
    'user-agent',
  ]) {
    const value = req.headers[name];
    if (typeof value === 'string') headers.set(name, value);
  }
  headers.set('origin', `https://${target.hostname}`);
  headers.set('referer', `https://${target.hostname}/`);
  if (!headers.has('user-agent')) {
    headers.set(
      'user-agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36',
    );
  }
  if (!headers.has('cookie') && FIXED_HOSTS.has(target.hostname)) {
    headers.set('cookie', 'CONSENT=YES+cb');
  }

  try {
    const hasBody = !['GET', 'HEAD'].includes(req.method);
    const upstream = await fetch(target, {
      method: req.method,
      headers,
      body: hasBody ? req : undefined,
      ...(hasBody ? { duplex: 'half' } : {}),
      redirect: 'manual',
    });

    res.statusCode = upstream.status;
    copyResponseHeaders(upstream, res);

    if (upstream.body) {
      await pipeline(Readable.fromWeb(upstream.body), res);
    } else {
      res.end();
    }
  } catch (error) {
    if (!res.headersSent) res.status(502).send('YouTube request failed');
    else res.destroy(error);
  }
};

module.exports.config = { api: { bodyParser: false } };
