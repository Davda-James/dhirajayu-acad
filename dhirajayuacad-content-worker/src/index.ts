import { jwtVerify } from 'jose';

export interface Env {
  COURSE_CONTENT_BUCKET: R2Bucket;
  JWT_SECRET: string;
}

interface JWTPayload {
  userId: string;
  email?: string;
  exp?: number;
  iat?: number;
}

const DEFAULT_MAX_CACHE_BYTES = 600 * 1024 * 1024; // 600 MB - allow caching large files (adjust as needed)

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Allow preflight
    if (request.method === 'OPTIONS') return handleCORS();

    // Only GET (media fetch)
    if (request.method !== 'GET') return new Response('Method Not Allowed', { status: 405 });

    const url = new URL(request.url);
    return handleFetch(request, env, ctx, url);
  },
};

async function handleFetch(request: Request, env: Env, ctx: ExecutionContext, url: URL): Promise<Response> {
  try {
    // Object path is the worker path without leading slash
    const objectPath = decodeURIComponent(url.pathname).replace(/^\//, '');
    if (!objectPath) return new Response('Not Found', { status: 404 });

		const isPublic = objectPath.startsWith('thumbnails/') || objectPath.startsWith('test/') || objectPath.startsWith('gallery/');

		// Verify JWT for protected assets only (videos, audios, docs etc.)
    if (!isPublic) {
      const auth = request.headers.get('Authorization') || '';
      if (!auth.startsWith('Bearer ')) return new Response('Unauthorized', { status: 401 });
      const token = auth.split(' ')[1];
      const jwtOk = await verifyJWTLocal(token, env);
      if (!jwtOk) return new Response('Unauthorized', { status: 401 });
    }

    // Range header support
    const rangeHeader = request.headers.get('Range');

    // Normalize cache key (strip query) so cached responses are reused across similar requests
    const requestOrigin = new URL(request.url).origin;
    const normalizedCacheUrl = `${requestOrigin}${url.pathname}`; // exclude query (sig/exp) for better cache hits
    const normalizedCacheKey = new Request(normalizedCacheUrl, { method: 'GET' });
    const cache = caches.default;

    // Only use the normalized cache for full GETs (no Range). Verify JWT first (done above), then check cache.
    if (!rangeHeader) {
      const cached = await cache.match(normalizedCacheKey).catch(() => null);
      if (cached) return addSecurityHeaders(cached);
    }

    // Fetch from R2 (forward range when requested). R2 GetOptions.range expects an R2Range or Headers (not a string).
    let r2obj: R2Object | null = null;
    if (rangeHeader) {
      try {
        // Preferred: forward as Headers so we preserve the original header semantics
        const rangeOpt = new Headers({ 'Range': rangeHeader });
        r2obj = await env.COURSE_CONTENT_BUCKET.get(objectPath, { range: rangeOpt });
      } catch (e) {
        // Fallback: parse `bytes=start-end` into an R2Range object (offset/length)
        const m = /bytes=(\d+)-(\d*)/.exec(rangeHeader);
        if (m) {
          const start = Number(m[1]);
          const end = m[2] ? Number(m[2]) : undefined;
          const r2Range: any = { offset: start };
          if (end !== undefined && !Number.isNaN(end) && end >= start) {
            r2Range.length = end - start + 1;
          }
          try {
            r2obj = await env.COURSE_CONTENT_BUCKET.get(objectPath, { range: r2Range });
          } catch (e2) {
            return new Response('Range request failed', { status: 400 });
          }
        } else {
					console.error('Invalid Range header format:', rangeHeader);
          return new Response('Invalid Range header', { status: 400 });
        }
      }
    } else {
      r2obj = await env.COURSE_CONTENT_BUCKET.get(objectPath);
    }

    if (!r2obj) return new Response('Not Found', { status: 404 });

    // Build headers
    const headers = new Headers();
    try { r2obj.writeHttpMetadata(headers); } catch (e) {}
    if (r2obj.httpEtag) headers.set('ETag', r2obj.httpEtag);

    // Conditional GET: If-None-Match
    const ifNoneMatch = request.headers.get('If-None-Match');
    if (ifNoneMatch && r2obj.httpEtag && ifNoneMatch === r2obj.httpEtag) {
      // return 304 with cache headers so client can reuse cached copy
      const nm = new Headers();
      try { r2obj.writeHttpMetadata(nm); } catch (e) {}
      if (r2obj.httpEtag) nm.set('ETag', r2obj.httpEtag);
      nm.set('Cache-Control', 'public, max-age=60');
      return new Response(null, { status: 304, headers: nm });
    }

    // Determine caching TTL based on path/type. Cache everything at the edge for speed.
    const cacheTtl = getCacheTime(objectPath);
    if (rangeHeader) {
      // for partial responses avoid caching the fragment for long
      headers.set('Cache-Control', 'no-store');
    } else {
      // Cache all full GET responses using the TTL derived from path/type
      headers.set('Cache-Control', `public, max-age=${cacheTtl}, s-maxage=${cacheTtl}`);
    }

    headers.set('Accept-Ranges', 'bytes');
    headers.set('Content-Disposition', 'inline');
    headers.set('X-Content-Type-Options', 'nosniff');

    // CORS: allow origins configured in function
    const headerOrigin = request.headers.get('Origin');
    if (headerOrigin && isAllowedOrigin(headerOrigin)) {
      headers.set('Access-Control-Allow-Origin', headerOrigin);
      headers.set('Access-Control-Allow-Credentials', 'true');
    }
    headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Authorization, Range');

    // Range handling & Content-Length/Content-Range
    let status = 200;
    if (rangeHeader) {
      status = 206;
      const objSize = r2obj.size ?? null;
      const contentRange = (r2obj.httpMetadata as any)?.['content-range'] || null;
      if (contentRange) {
        headers.set('Content-Range', contentRange);
      } else if (objSize != null) {
        const m = /bytes=(\d+)-(\d*)/.exec(rangeHeader);
        if (m) {
          const start = Number(m[1]);
          const end = m[2] ? Number(m[2]) : (objSize - 1);
          headers.set('Content-Range', `bytes ${start}-${end}/${objSize}`);
          headers.set('Content-Length', String(end - start + 1));
        }
      }
    } else {
      if (r2obj.size != null) headers.set('Content-Length', String(r2obj.size));
    }

    // Stream body safely (use any cast for TypeScript)
    const bodyStream = (r2obj as any).body as ReadableStream<Uint8Array> | null | undefined;
    const response = new Response(bodyStream ?? null, { status, headers });

    // Cache at edge: store under the normalized key for full responses only
    if (!rangeHeader) {
      try {
        ctx.waitUntil(cache.put(normalizedCacheKey, response.clone()));
      } catch (e) {
        console.warn('Cache put failed', e);
      }
    }

    return response;
  } catch (err) {
    console.error('Worker error:', err);
    return new Response('Internal Server Error', { status: 500 });
  }
}

async function verifyJWTLocal(token: string, env: Env): Promise<JWTPayload | null> {
  try {
    const secret = new TextEncoder().encode(env.JWT_SECRET);
    const { payload } = await jwtVerify(token, secret, { algorithms: ['HS256'] });
    const userId = (payload as any).userId as string || (payload as any).sub as string;
    if (!userId) return null;
    return {
      userId,
      email: (payload as any).email as string | undefined,
      exp: (payload as any).exp as number | undefined,
      iat: (payload as any).iat as number | undefined,
    };
  } catch (e) {
    console.error('JWT verify failed:', e);
    return null;
  }
}

function getCacheTime(path: string): number {
  // longer TTL for thumbnails/images, moderate for docs, shorter for videos/audios
  if (path.match(/\.(jpg|jpeg|png|webp)$/i) || path.startsWith('thumbnails/') || path.startsWith('test/')) return 2592000;
  if (path.startsWith('docs/') || path.match(/\.(pdf|docx?)$/i)) return 604800; // 7 days
  if (path.startsWith('videos/') || path.startsWith('audios/') || path.match(/\.(mp4|mp3|mov)$/i)) return 86400; // 1 day
  return 3600; // default 1 hour
}

function isAllowedOrigin(origin: string): boolean {
  const allowed = ['https://yourdomain.com', 'https://www.yourdomain.com', 'http://localhost:3000', 'http://localhost:5173'];
  return allowed.includes(origin);
}

function addSecurityHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set('Content-Disposition', 'inline');
  headers.set('X-Content-Type-Options', 'nosniff');
  return new Response(response.body, { status: response.status, headers });
}

function handleCORS(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Range, Content-Type',
      'Access-Control-Max-Age': '86400',
    },
  });
}
