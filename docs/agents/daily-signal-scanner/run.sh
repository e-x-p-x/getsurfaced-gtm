#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Daily Signal Scanner — Shell Wrapper
# Pattern: Dual-Layer Pipeline
# Schedule: Weekdays at 08:00
#
# Scans Reddit and web for GEO/AI search buying signals,
# scores them against the ICP, and produces a daily brief
# with draft outreach messages.
# ============================================================

# --- Configuration ---
AGENT_NAME="daily-signal-scanner"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
PROMPT_FILE="${SCRIPT_DIR}/prompt.md"
ICP_FILE="${PROJECT_ROOT}/docs/icp.md"
SEQUENCES_DIR="${PROJECT_ROOT}/docs/sequences"
REPORTS_DIR="${PROJECT_ROOT}/docs/reports/daily"
PROCESSED_IDS="${LOG_DIR}/processed_ids.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TODAY=$(date +%Y-%m-%d)

mkdir -p "$LOG_DIR" "$REPORTS_DIR"

# Initialize processed IDs file if it doesn't exist
if [ ! -f "$PROCESSED_IDS" ]; then
    echo '[]' > "$PROCESSED_IDS"
fi

# --- Logging ---
LOG_FILE="${LOG_DIR}/${AGENT_NAME}_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== ${AGENT_NAME} starting at $(date) ==="

# --- Gate Check (prevent double-runs) ---
GATE_FILE="${LOG_DIR}/${AGENT_NAME}_last_run.txt"
MIN_HOURS=20

if [ -f "$GATE_FILE" ]; then
    last_run=$(cat "$GATE_FILE")
    now=$(date +%s)
    hours_since=$(( (now - last_run) / 3600 ))
    if [ "$hours_since" -lt "$MIN_HOURS" ]; then
        echo "Gate: ${hours_since}h since last run (min: ${MIN_HOURS}h). Skipping."
        exit 0
    fi
fi

# --- Layer 1: Reddit Data Acquisition ---
echo "--- Layer 1: Scraping Reddit ---"

RAW_REDDIT=$(mktemp "${TMPDIR:-/tmp}/${AGENT_NAME}_reddit_raw_XXXXXX.json")
STRIPPED_REDDIT=$(mktemp "${TMPDIR:-/tmp}/${AGENT_NAME}_reddit_stripped_XXXXXX.json")

# Subreddits to monitor (from ICP community discovery)
SUBREDDITS=("SEO" "bigseo" "SEO_and_AI" "DigitalMarketing" "TechSEO")

# Search keywords (from ICP language patterns)
KEYWORDS=("GEO+optimization" "AI+search+visibility" "ChatGPT+brand+mention" "LLM+optimization" "generative+engine+optimization" "AI+search+tool")

echo '[]' > "$RAW_REDDIT"

for sub in "${SUBREDDITS[@]}"; do
    for keyword in "${KEYWORDS[@]}"; do
        REDDIT_URL="https://www.reddit.com/r/${sub}/search.json?q=${keyword}&sort=new&t=day&limit=10&restrict_sr=1"
        TEMP_RESPONSE=$(mktemp "${TMPDIR:-/tmp}/${AGENT_NAME}_reddit_resp_XXXXXX.json")

        HTTP_STATUS=$(curl -s -o "$TEMP_RESPONSE" -w "%{http_code}" \
            -H "User-Agent: DailySignalScanner/1.0" \
            "$REDDIT_URL" 2>/dev/null || echo "000")

        if [ "$HTTP_STATUS" = "200" ] && [ -s "$TEMP_RESPONSE" ]; then
            # Merge new posts into the collection
            python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        existing = json.load(f)
    with open(sys.argv[2]) as f:
        response = json.load(f)
    posts = response.get('data', {}).get('children', [])
    for post in posts:
        d = post.get('data', {})
        existing.append({
            'source': 'reddit',
            'id': d.get('id', ''),
            'subreddit': d.get('subreddit', ''),
            'title': d.get('title', ''),
            'url': f\"https://reddit.com{d.get('permalink', '')}\",
            'score': d.get('score', 0),
            'num_comments': d.get('num_comments', 0),
            'author': d.get('author', ''),
            'selftext': (d.get('selftext', '') or '')[:500],
            'created_utc': d.get('created_utc', 0)
        })
    with open(sys.argv[1], 'w') as f:
        json.dump(existing, f)
except Exception as e:
    print(f'Warning: Failed to parse response for r/{sys.argv[3]}: {e}', file=sys.stderr)
" "$RAW_REDDIT" "$TEMP_RESPONSE" "$sub"
        fi

        rm -f "$TEMP_RESPONSE"
        sleep 1  # Rate limit: 1 request/second for Reddit
    done
done

# --- Dedup against previously processed items ---
echo "--- Deduplicating ---"

python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    raw = json.load(f)
with open(sys.argv[2]) as f:
    processed = json.load(f)

processed_set = set(processed)

# Dedup by ID and URL
seen = set()
unique = []
for item in raw:
    key = item.get('id') or item.get('url', '')
    if key and key not in processed_set and key not in seen:
        seen.add(key)
        unique.append(item)

with open(sys.argv[3], 'w') as f:
    json.dump(unique, f, indent=2)

print(f'Raw: {len(raw)} | After dedup: {len(unique)} | Previously seen: {len(raw) - len(unique)}')
" "$RAW_REDDIT" "$PROCESSED_IDS" "$STRIPPED_REDDIT"

ITEM_COUNT=$(python3 -c "import json; print(len(json.load(open('$STRIPPED_REDDIT'))))")
echo "New signals to process: ${ITEM_COUNT}"

if [ "$ITEM_COUNT" -eq 0 ]; then
    echo "No new signals found. Nothing to process."
    rm -f "$RAW_REDDIT" "$STRIPPED_REDDIT"
    date +%s > "$GATE_FILE"
    echo "=== ${AGENT_NAME} completed (no data) at $(date) ==="
    exit 0
fi

# --- Build Full Prompt ---
echo "--- Building prompt ---"
FULL_PROMPT=$(mktemp "${TMPDIR:-/tmp}/${AGENT_NAME}_prompt_XXXXXX.md")

{
    cat "$PROMPT_FILE"

    echo ""
    echo "---"
    echo ""
    echo "## ICP Context"
    echo ""
    cat "$ICP_FILE"

    echo ""
    echo "---"
    echo ""
    echo "## Available Outreach Sequences"
    echo ""
    for seq_file in "$SEQUENCES_DIR"/*.md; do
        if [ -f "$seq_file" ] && [ "$(basename "$seq_file")" != "README.md" ]; then
            echo "### $(basename "$seq_file" .md)"
            head -30 "$seq_file"
            echo ""
            echo "..."
            echo ""
        fi
    done

    echo "---"
    echo ""
    echo "## Today's Signals (Pre-Scraped Data)"
    echo ""
    echo '```json'
    cat "$STRIPPED_REDDIT"
    echo '```'
    echo ""
    echo "## Today's Date: ${TODAY}"
    echo ""
    echo "## Output File Path: ${REPORTS_DIR}/${TODAY}.md"

} > "$FULL_PROMPT"

# --- Claude Invocation ---
echo "--- Invoking Claude Sonnet ---"

cat "$FULL_PROMPT" | claude -p \
    --model sonnet \
    --max-turns 5 \
    --allowedTools "WebSearch,Read,Write"

CLAUDE_EXIT=$?
if [ "$CLAUDE_EXIT" -ne 0 ]; then
    echo "ERROR: Claude exited with code ${CLAUDE_EXIT}"
    rm -f "$RAW_REDDIT" "$STRIPPED_REDDIT" "$FULL_PROMPT"
    exit 1
fi

# --- Update Processed IDs ---
echo "--- Updating processed IDs ---"

python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    new_items = json.load(f)
with open(sys.argv[2]) as f:
    processed = json.load(f)

new_ids = [item.get('id') or item.get('url', '') for item in new_items if item.get('id') or item.get('url')]
processed.extend(new_ids)

# Keep only the last 5000 IDs to prevent the file from growing forever
processed = processed[-5000:]

with open(sys.argv[2], 'w') as f:
    json.dump(processed, f)

print(f'Added {len(new_ids)} IDs to processed log (total: {len(processed)})')
" "$STRIPPED_REDDIT" "$PROCESSED_IDS"

# --- Cleanup ---
rm -f "$RAW_REDDIT" "$STRIPPED_REDDIT" "$FULL_PROMPT"
date +%s > "$GATE_FILE"
echo "=== ${AGENT_NAME} completed at $(date) ==="
