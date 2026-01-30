#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8081"
EMAIL="demo-$(date +%s)@example.com"
PASS="Password123!"

pretty_json() {
  # crude but works for demo output; avoids jq dependency
  python - <<'PY' 2>/dev/null || cat
import json,sys
print(json.dumps(json.load(sys.stdin), indent=2))
PY
}

http_code() {
  # prints only http status code
  curl -s -o /dev/null -w "%{http_code}" "$@"
}

echo "== 1) Register =="
REG_JSON=$(curl -s -X POST "$BASE/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")

echo "$REG_JSON" | pretty_json

ACCESS=$(echo "$REG_JSON" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
REFRESH=$(echo "$REG_JSON" | sed -n 's/.*"refreshToken":"\([^"]*\)".*/\1/p')

[ -n "$ACCESS" ] || { echo "ERROR: accessToken not found"; exit 1; }
[ -n "$REFRESH" ] || { echo "ERROR: refreshToken not found"; exit 1; }

echo
echo "== 2) /v1/me (should be 200) =="
CODE=$(http_code -H "Authorization: Bearer $ACCESS" "$BASE/v1/me")
echo "HTTP $CODE"
[ "$CODE" = "200" ] || { echo "ERROR: /v1/me expected 200"; exit 1; }

echo
echo "== 3) Refresh =="
REFRESH_JSON=$(curl -s -X POST "$BASE/v1/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH\"}")

echo "$REFRESH_JSON" | pretty_json

NEW_ACCESS=$(echo "$REFRESH_JSON" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
NEW_REFRESH=$(echo "$REFRESH_JSON" | sed -n 's/.*"refreshToken":"\([^"]*\)".*/\1/p')

[ -n "$NEW_ACCESS" ] || { echo "ERROR: new accessToken not found"; exit 1; }
[ -n "$NEW_REFRESH" ] || { echo "ERROR: new refreshToken not found"; exit 1; }

echo
echo "== 4) /v1/me with NEW access token (should be 200) =="
CODE=$(http_code -H "Authorization: Bearer $NEW_ACCESS" "$BASE/v1/me")
echo "HTTP $CODE"
[ "$CODE" = "200" ] || { echo "ERROR: /v1/me expected 200"; exit 1; }

echo
echo "== 5) Logout (should be 204) =="
CODE=$(http_code -X POST "$BASE/v1/auth/logout" \
  -H "Authorization: Bearer $NEW_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$NEW_REFRESH\"}")
echo "HTTP $CODE"
[ "$CODE" = "204" ] || { echo "ERROR: logout expected 204"; exit 1; }

echo
echo "== 6) Refresh again with revoked token (should be 401) =="
CODE=$(http_code -X POST "$BASE/v1/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$NEW_REFRESH\"}")
echo "HTTP $CODE"
[ "$CODE" = "401" ] || { echo "ERROR: refresh-after-logout expected 401"; exit 1; }

echo
echo "DONE ----  Demo smoke test passed"
