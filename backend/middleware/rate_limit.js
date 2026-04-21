// backend/middleware/rate_limit.js
// Redis sliding window rate limiter for all Lambda endpoints

const { createClient } = require('redis');

let redisClient = null;

async function getRedis() {
  if (redisClient && redisClient.isReady) return redisClient;
  redisClient = createClient({ url: process.env.REDIS_URL || 'redis://localhost:6379' });
  redisClient.on('error', (e) => console.warn('Redis error:', e.message));
  try { await redisClient.connect(); } catch (e) { console.warn('Redis unavailable, skipping rate limit'); return null; }
  return redisClient;
}

/**
 * Rate limit check
 * @param {string} key      — unique identifier (userId or IP)
 * @param {number} limit    — max requests
 * @param {number} windowSec — time window in seconds
 * @returns {{ allowed: boolean, remaining: number, resetIn: number }}
 */
async function checkRateLimit(key, limit = 100, windowSec = 60) {
  const redis = await getRedis();
  if (!redis) return { allowed: true, remaining: limit, resetIn: windowSec };

  const now   = Date.now();
  const winMs = windowSec * 1000;
  const rKey  = `rl:${key}`;

  try {
    const pipe = redis.multi();
    pipe.zRemRangeByScore(rKey, '-inf', now - winMs);
    pipe.zCard(rKey);
    pipe.zAdd(rKey, { score: now, value: `${now}-${Math.random()}` });
    pipe.expire(rKey, windowSec + 1);
    const results = await pipe.exec();

    const count = results[1] || 0;
    const allowed = count < limit;

    return {
      allowed,
      remaining: Math.max(0, limit - count - 1),
      resetIn: windowSec,
    };
  } catch (e) {
    console.warn('Rate limit error:', e.message);
    return { allowed: true, remaining: limit, resetIn: windowSec };
  }
}

// Per-endpoint limits
const LIMITS = {
  auth:      { limit:  10, window: 60  },  // 10 auth attempts/min
  export:    { limit:   5, window: 3600 }, // 5 exports/hour
  ai:        { limit:  20, window: 60  },  // 20 AI calls/min
  templates: { limit: 200, window: 60  },  // 200 reads/min
  default:   { limit: 100, window: 60  },  // 100 general/min
};

/**
 * Middleware wrapper for Lambda handlers
 */
function withRateLimit(handler, type = 'default') {
  return async (event) => {
    const { limit, window } = LIMITS[type] || LIMITS.default;

    // Extract identifier (userId from JWT or IP)
    const ip = event.requestContext?.identity?.sourceIp || 'unknown';
    let identifier = ip;

    try {
      const h = event.headers?.Authorization || event.headers?.authorization || '';
      if (h.startsWith('Bearer ')) {
        const payload = JSON.parse(Buffer.from(h.split('.')[1], 'base64').toString());
        identifier = `user:${payload.sub}`;
      }
    } catch (_) {}

    const key = `${type}:${identifier}`;
    const { allowed, remaining, resetIn } = await checkRateLimit(key, limit, window);

    if (!allowed) {
      return {
        statusCode: 429,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'X-RateLimit-Limit': String(limit),
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Reset': String(resetIn),
          'Retry-After': String(resetIn),
        },
        body: JSON.stringify({ error: 'Too many requests. Please slow down.', retryAfter: resetIn }),
      };
    }

    const response = await handler(event);
    return {
      ...response,
      headers: {
        ...(response.headers || {}),
        'X-RateLimit-Limit': String(limit),
        'X-RateLimit-Remaining': String(remaining),
        'X-RateLimit-Reset': String(resetIn),
      },
    };
  };
}

module.exports = { checkRateLimit, withRateLimit, LIMITS };
