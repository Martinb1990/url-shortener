// k6 load test: a realistic mix for a URL shortener (mostly redirects,
// some link creation), with pass/fail thresholds.
//   k6 run -e BASE_URL=http://localhost:8080 tests/load/shortener.js
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = (__ENV.BASE_URL || 'http://localhost:8080').replace(/\/$/, '');

export const options = {
  scenarios: {
    // Readers: follow existing short links (the hot path, served from cache).
    redirects: {
      executor: 'ramping-vus',
      exec: 'follow',
      startVUs: 0,
      stages: [
        { duration: '15s', target: 20 },
        { duration: '30s', target: 20 },
        { duration: '10s', target: 0 },
      ],
    },
    // Writers: create new links at a steady rate.
    creates: {
      executor: 'constant-arrival-rate',
      exec: 'create',
      rate: 5,
      timeUnit: '1s',
      duration: '55s',
      preAllocatedVUs: 5,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],                        // < 1% errors
    'http_req_duration{scenario:redirects}': ['p(95)<300'], // redirects: p95 < 300 ms
    'http_req_duration{scenario:creates}': ['p(95)<500'],   // creates:   p95 < 500 ms
    checks: ['rate>0.99'],
  },
};

const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

// Seed a pool of links once; readers pick from it.
export function setup() {
  const codes = [];
  for (let i = 0; i < 50; i++) {
    const res = http.post(`${BASE}/api/links`, JSON.stringify({ url: `https://example.com/seed/${i}` }), JSON_HEADERS);
    if (res.status === 201) codes.push(res.json('code'));
  }
  if (codes.length === 0) throw new Error(`could not seed links against ${BASE}`);
  return { codes };
}

export function follow(data) {
  const code = data.codes[Math.floor(Math.random() * data.codes.length)];
  // Don't follow the redirect: we measure our service, not example.com.
  const res = http.get(`${BASE}/${code}`, { redirects: 0, tags: { name: 'GET /{code}' } });
  check(res, { 'redirect is 307': (r) => r.status === 307 });
  sleep(0.2);
}

export function create() {
  const res = http.post(
    `${BASE}/api/links`,
    JSON.stringify({ url: `https://example.com/load/${__VU}-${__ITER}-${Date.now()}` }),
    { ...JSON_HEADERS, tags: { name: 'POST /api/links' } },
  );
  check(res, { 'create is 201': (r) => r.status === 201 });
}
