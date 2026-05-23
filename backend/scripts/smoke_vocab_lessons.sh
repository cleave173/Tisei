#!/usr/bin/env bash
# E2E smoke test for vocab-lessons endpoints.
# Usage: BASE_URL=http://localhost:8001 TOKEN=<your_access_token> bash smoke_vocab_lessons.sh
# If TOKEN is unset, the script will log in with test credentials first.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8001}"
EMAIL="${EMAIL:-testuser@example.com}"
PASSWORD="${PASSWORD:-testpass123}"

if [[ -z "${TOKEN:-}" ]]; then
  echo ">>> Logging in as $EMAIL ..."
  TOKEN=$(curl -sf "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
  echo "    Token acquired."
fi

AUTH="-H \"Authorization: Bearer $TOKEN\""

echo ""
echo ">>> 1. List topics (language=en, user-level filtered) ..."
TOPICS=$(curl -sf "$BASE_URL/api/v1/languages/en/topics" \
  -H "Authorization: Bearer $TOKEN")
echo "$TOPICS" | python3 -c "
import sys, json
ts = json.load(sys.stdin)
print(f'    {len(ts)} topics returned')
for t in ts[:3]:
    print(f'    id={t[\"id\"]} slug={t[\"slug\"]} level={t[\"level\"]} lessons={t[\"lessons_count\"]} completed={t[\"completed_lessons\"]}')
"

TOPIC_ID=$(echo "$TOPICS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo ""
echo ">>> 2. List vocab lessons for topic $TOPIC_ID ..."
LESSONS=$(curl -sf "$BASE_URL/api/v1/vocab-lessons/topic/$TOPIC_ID" \
  -H "Authorization: Bearer $TOKEN")
echo "$LESSONS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ls = d['lessons']
print(f'    topic: {d[\"topic_title\"]} ({d[\"topic_level\"]}), {len(ls)} lessons, size={d[\"lesson_size\"]}')
for l in ls:
    p = l['progress']
    print(f'    lesson {l[\"index\"]}: {len(l[\"words\"])} words | cards={p[\"cards_done\"]} listening={p[\"listening_done\"]} mc={p[\"mc_done\"]} speaking={p[\"speaking_done\"]} completed={p[\"is_completed\"]}')
"

echo ""
echo ">>> 3. Mark cards stage complete for lesson 0 ..."
STAGE_RES=$(curl -sf -X POST \
  "$BASE_URL/api/v1/vocab-lessons/topic/$TOPIC_ID/0/stage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"stage":"cards"}')
echo "$STAGE_RES" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'    xp_earned_now={d[\"xp_earned_now\"]} cards_done={d[\"progress\"][\"cards_done\"]}')
"

echo ""
echo ">>> 4. Mark listening stage ..."
STAGE_RES=$(curl -sf -X POST \
  "$BASE_URL/api/v1/vocab-lessons/topic/$TOPIC_ID/0/stage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"stage":"listening"}')
echo "$STAGE_RES" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'    xp_earned_now={d[\"xp_earned_now\"]} listening_done={d[\"progress\"][\"listening_done\"]}')
"

echo ""
echo ">>> 5. Mark MC stage ..."
STAGE_RES=$(curl -sf -X POST \
  "$BASE_URL/api/v1/vocab-lessons/topic/$TOPIC_ID/0/stage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"stage":"mc"}')
echo "$STAGE_RES" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'    xp_earned_now={d[\"xp_earned_now\"]} mc_done={d[\"progress\"][\"mc_done\"]}')
"

echo ""
echo ">>> 6. Mark speaking stage (should complete lesson) ..."
STAGE_RES=$(curl -sf -X POST \
  "$BASE_URL/api/v1/vocab-lessons/topic/$TOPIC_ID/0/stage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"stage":"speaking"}')
echo "$STAGE_RES" | python3 -c "
import sys, json
d = json.load(sys.stdin)
p = d['progress']
print(f'    xp_earned_now={d[\"xp_earned_now\"]} is_completed={p[\"is_completed\"]} total_xp={p[\"xp_earned\"]}')
"

echo ""
echo ">>> 7. Verify topics shows completed_lessons=1 ..."
curl -sf "$BASE_URL/api/v1/languages/en/topics" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "
import sys, json
ts = json.load(sys.stdin)
t = next((t for t in ts if t['id'] == $TOPIC_ID), None)
print(f'    topic {t[\"slug\"]}: completed_lessons={t[\"completed_lessons\"]}')
print()
print('=== SMOKE TEST PASSED ===')
"
