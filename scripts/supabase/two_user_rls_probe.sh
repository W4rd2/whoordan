#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL to https://<project-ref>.supabase.co}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY to the public publishable/anon key}"
: "${RLS_PROBE_USER_A_EMAIL:?Set RLS_PROBE_USER_A_EMAIL}"
: "${RLS_PROBE_USER_A_PASSWORD:?Set RLS_PROBE_USER_A_PASSWORD}"
: "${RLS_PROBE_USER_B_EMAIL:?Set RLS_PROBE_USER_B_EMAIL}"
: "${RLS_PROBE_USER_B_PASSWORD:?Set RLS_PROBE_USER_B_PASSWORD}"

auth_token() {
  local email="$1"
  local password="$2"
  curl -fsS \
    -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])'
}

jwt_sub() {
  python3 - "$1" <<'PY'
import base64, json, sys
token = sys.argv[1]
payload = token.split('.')[1]
payload += '=' * (-len(payload) % 4)
print(json.loads(base64.urlsafe_b64decode(payload.encode()))['sub'])
PY
}

rest() {
  local method="$1"
  local path="$2"
  local token="${3:-}"
  local data="${4:-}"
  local extra_prefer="${5:-}"
  local tmp
  tmp="$(mktemp)"
  local args=(
    -sS
    -o "$tmp"
    -w "%{http_code}"
    -X "$method"
    "$SUPABASE_URL/rest/v1/$path"
    -H "apikey: $SUPABASE_PUBLISHABLE_KEY"
    -H "Content-Type: application/json"
  )
  if [[ -n "$token" ]]; then
    args+=(-H "Authorization: Bearer $token")
  fi
  if [[ -n "$extra_prefer" ]]; then
    args+=(-H "Prefer: $extra_prefer")
  fi
  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi
  local status
  status="$(curl "${args[@]}")"
  printf '%s\n' "$status"
  cat "$tmp"
  rm -f "$tmp"
}

assert_status() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL %s: expected HTTP %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS %s\n' "$label"
}

assert_status_one_of() {
  local actual="$1"
  local label="$2"
  shift 2
  local expected
  for expected in "$@"; do
    if [[ "$actual" == "$expected" ]]; then
      printf 'PASS %s\n' "$label"
      return 0
    fi
  done
  printf 'FAIL %s: expected one of [%s], got %s\n' "$label" "$*" "$actual" >&2
  exit 1
}

assert_json_length() {
  local expected="$1"
  local body="$2"
  local label="$3"
  local actual
  actual="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' <<<"$body")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL %s: expected %s row(s), got %s\n%s\n' "$label" "$expected" "$actual" "$body" >&2
    exit 1
  fi
  printf 'PASS %s\n' "$label"
}

TOKEN_A="$(auth_token "$RLS_PROBE_USER_A_EMAIL" "$RLS_PROBE_USER_A_PASSWORD")"
TOKEN_B="$(auth_token "$RLS_PROBE_USER_B_EMAIL" "$RLS_PROBE_USER_B_PASSWORD")"
USER_A="$(jwt_sub "$TOKEN_A")"
USER_B="$(jwt_sub "$TOKEN_B")"
RUN_ID="rls-probe-$(date -u +%Y%m%d%H%M%S)"

row_payload() {
  local user_id="$1"
  local dedupe_key="$2"
  local note="$3"
  python3 - "$user_id" "$dedupe_key" "$note" <<'PY'
import json, sys
print(json.dumps({
  "user_id": sys.argv[1],
  "scope": "cloud_sync",
  "decision": "denied",
  "policy_version": "rls-probe",
  "note": sys.argv[3],
  "dedupe_key": sys.argv[2],
  "sync_status": "pending",
  "sync_version": 1,
  "conflict_status": "none"
}))
PY
}

account_deletion_payload() {
  local user_id="$1"
  local email="$2"
  python3 - "$user_id" "$email" <<'PY'
import json, sys
print(json.dumps({
  "user_id": sys.argv[1],
  "email": sys.argv[2],
  "status": "pending"
}))
PY
}

status_body="$(rest POST "consent_records?on_conflict=user_id,dedupe_key" "$TOKEN_A" "$(row_payload "$USER_A" "$RUN_ID-a" "owned by user A")" "resolution=merge-duplicates,return=representation")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "201" "$status" "user A can write own row"
assert_json_length "1" "$body" "user A insert returned own row"

status_body="$(rest POST "consent_records?on_conflict=user_id,dedupe_key" "$TOKEN_B" "$(row_payload "$USER_B" "$RUN_ID-b" "owned by user B")" "resolution=merge-duplicates,return=representation")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "201" "$status" "user B can write own row"
assert_json_length "1" "$body" "user B insert returned own row"

status_body="$(rest GET "consent_records?dedupe_key=eq.$RUN_ID-a&select=id,user_id,dedupe_key,note" "$TOKEN_A")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user A can read own row"
assert_json_length "1" "$body" "user A own select"

status_body="$(rest GET "consent_records?dedupe_key=eq.$RUN_ID-b&select=id,user_id,dedupe_key,note" "$TOKEN_B")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user B can read own row"
assert_json_length "1" "$body" "user B own select"

status_body="$(rest GET "consent_records?dedupe_key=eq.$RUN_ID-b&select=id,user_id,dedupe_key,note" "$TOKEN_A")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user A cross-user read request succeeds safely"
assert_json_length "0" "$body" "user A cannot read user B row"

status_body="$(rest PATCH "consent_records?dedupe_key=eq.$RUN_ID-b" "$TOKEN_A" '{"note":"cross-user update should not apply"}' "return=representation")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user A cross-user update request succeeds safely"
assert_json_length "0" "$body" "user A cannot update user B row"

status_body="$(rest DELETE "consent_records?dedupe_key=eq.$RUN_ID-b" "$TOKEN_A" "" "return=representation")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user A cross-user delete request succeeds safely"
assert_json_length "0" "$body" "user A cannot delete user B row"

status_body="$(rest GET "consent_records?dedupe_key=eq.$RUN_ID-b&select=id,user_id,dedupe_key,note" "$TOKEN_B")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user B row remains after user A cross-user delete"
assert_json_length "1" "$body" "user B row still visible to owner"

status_body="$(rest GET "consent_records?dedupe_key=eq.$RUN_ID-a&select=id,user_id,dedupe_key,note")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "unauthenticated private-row read request succeeds safely"
assert_json_length "0" "$body" "unauthenticated user cannot read private rows"

status_body="$(rest POST "account_deletion_requests" "$TOKEN_A" "$(account_deletion_payload "$USER_A" "$RLS_PROBE_USER_A_EMAIL")" "return=representation")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "201" "$status" "user A can request own account deletion"
assert_json_length "1" "$body" "user A deletion request returned own row"

status_body="$(rest GET "account_deletion_requests?user_id=eq.$USER_A&select=id,user_id,status" "$TOKEN_A")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user A can read own account deletion request"
assert_json_length "1" "$body" "user A sees own account deletion request"

status_body="$(rest GET "account_deletion_requests?user_id=eq.$USER_A&select=id,user_id,status" "$TOKEN_B")"
status="$(head -n1 <<<"$status_body")"
body="$(tail -n +2 <<<"$status_body")"
assert_status "200" "$status" "user B cross-user deletion-request read succeeds safely"
assert_json_length "0" "$body" "user B cannot read user A deletion request"

status_body="$(rest GET "account_deletion_requests?user_id=eq.$USER_A&select=id,user_id,status")"
status="$(head -n1 <<<"$status_body")"
assert_status_one_of "$status" "unauthenticated deletion-request read is denied safely" "401" "403"

rest PATCH "account_deletion_requests?user_id=eq.$USER_A&status=eq.pending" "$TOKEN_A" '{"status":"canceled"}' >/dev/null
rest DELETE "consent_records?dedupe_key=eq.$RUN_ID-a" "$TOKEN_A" "" >/dev/null
rest DELETE "consent_records?dedupe_key=eq.$RUN_ID-b" "$TOKEN_B" "" >/dev/null

printf 'PASS two-user RLS probe completed without exposing tokens.\n'
