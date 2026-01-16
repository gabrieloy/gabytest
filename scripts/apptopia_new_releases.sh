#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   APPTOPIA_CLIENT=... APPTOPIA_SECRET=... [/optional envs] /workspace/scripts/apptopia_new_releases.sh
#
# Optional env vars:
#   OUTPUT_PATH  - where to save the JSON (default: /workspace/output/apptopia_new_releases_google_play.json)
#   STORE        - store identifier (default: google_play)
#   QUIET        - set to 1 to suppress non-essential logs
#
# Notes:
# - Tries both endpoint variants and both auth header formats used in Apptopia docs/examples.
# - Requires curl and python3; jq is optional.

OUTPUT_PATH=${OUTPUT_PATH:-/workspace/output/apptopia_new_releases_google_play.json}
STORE=${STORE:-google_play}
QUIET=${QUIET:-0}

log() {
	if [ "$QUIET" != "1" ]; then
		echo "$@"
	fi
}

require_env() {
	local name="$1"
	if [ -z "${!name:-}" ]; then
		echo "Missing required environment variable: $name" >&2
		echo "Example: APPTOPIA_CLIENT=... APPTOPIA_SECRET=... $0" >&2
		exit 2
	fi
}

require_env APPTOPIA_CLIENT
require_env APPTOPIA_SECRET

mkdir -p "$(dirname "$OUTPUT_PATH")"
TMP1=$(mktemp)
TMP2=$(mktemp)
trap 'rm -f "$TMP1" "$TMP2"' EXIT

log "Authenticating with Apptopia..."
LOGIN_RESP=$(curl -sS -X POST "https://integrations.apptopia.com/api/login" \
	-H "Content-Type: application/x-www-form-urlencoded" \
	--data-urlencode "client=${APPTOPIA_CLIENT}" \
	--data-urlencode "secret=${APPTOPIA_SECRET}")

# Extract token using Python to avoid dependency on jq
TOKEN=$(python3 - "$LOGIN_RESP" <<'PY'
import sys, json
try:
	data = json.loads(sys.argv[1])
	print(data.get('token', ''))
except Exception:
	print("")
PY
)

if [ -z "$TOKEN" ]; then
	echo "Login failed: did not receive a token. Check your Client ID/Secret and API access." >&2
	echo "Raw login response (truncated):" >&2
	echo "$LOGIN_RESP" | head -c 1000 >&2
	exit 1
fi

log "Login successful. Fetching new releases for store=${STORE}..."

# Variant 1: /api/google_play/new_releases with Authorization: <token>
HTTP1=$(curl -sS -o "$TMP1" -w "%{http_code}" \
	-H "Authorization: ${TOKEN}" \
	"https://integrations.apptopia.com/api/${STORE}/new_releases")

if [ "$HTTP1" = "200" ]; then
	log "Received data from /api/${STORE}/new_releases (Authorization: <token>)."
	cat "$TMP1" | tee "$OUTPUT_PATH" >/dev/null
	exit 0
fi

# Variant 2: /api/new_releases?store=<store> with Authorization: Bearer <token>
HTTP2=$(curl -sS -o "$TMP2" -w "%{http_code}" \
	-H "Authorization: Bearer ${TOKEN}" \
	"https://integrations.apptopia.com/api/new_releases?store=${STORE}")

if [ "$HTTP2" = "200" ]; then
	log "Received data from /api/new_releases?store=${STORE} (Authorization: Bearer <token>)."
	cat "$TMP2" | tee "$OUTPUT_PATH" >/dev/null
	exit 0
fi

# Neither variant succeeded
{
	echo "Both new releases endpoint variants failed."
	echo "Status1: ${HTTP1}  Endpoint: /api/${STORE}/new_releases"
	[ -s "$TMP1" ] && { echo "--- Response 1 (truncated) ---"; head -c 1000 "$TMP1"; echo; }
	echo "Status2: ${HTTP2}  Endpoint: /api/new_releases?store=${STORE}"
	[ -s "$TMP2" ] && { echo "--- Response 2 (truncated) ---"; head -c 1000 "$TMP2"; echo; }
} >&2
exit 3