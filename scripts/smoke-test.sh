#!/usr/bin/env bash
# End-to-end smoke test against a running instance.
#   ./scripts/smoke-test.sh [base-url]     (default http://localhost:8000)
set -euo pipefail

BASE="${1:-http://localhost:8000}"
BASE="${BASE%/}"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "==> Waiting for $BASE/readyz"
for _ in $(seq 1 30); do
  if curl -fsS "$BASE/readyz" >/dev/null 2>&1; then break; fi
  sleep 2
done
ready=$(curl -fsS "$BASE/readyz") || fail "app never became ready"
echo "    $ready"

echo "==> Create a link"
target="https://example.com/smoke/$(date +%s)"
created=$(curl -fsS -X POST "$BASE/api/links" -H 'Content-Type: application/json' \
  -d "{\"url\": \"$target\"}") || fail "create failed"
code=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["code"])' <<<"$created")
echo "    code=$code"

echo "==> Follow it"
status=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/$code")
location=$(curl -s -o /dev/null -w '%{redirect_url}' "$BASE/$code")
[[ $status == 307 ]] || fail "expected 307, got $status"
[[ $location == "$target" ]] || fail "expected redirect to $target, got $location"

echo "==> Click counted"
clicks=$(curl -fsS "$BASE/api/links/$code" | python3 -c 'import json,sys; print(json.load(sys.stdin)["clicks"])')
[[ $clicks == 2 ]] || fail "expected 2 clicks, got $clicks"

echo "==> Metrics exposed"
curl -fsS "$BASE/metrics" | grep -q '^shortener_links_created_total' || fail "metric missing"

echo "==> Frontend served"
curl -fsS "$BASE/" | grep -q 'Shortly' || fail "index page missing"

echo "All smoke tests passed."
