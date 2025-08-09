#!/usr/bin/env bash
set -euo pipefail

# Publish Remote Config via REST using Application Default Credentials or explicit token
# Usage:
#   export PROJECT_ID=talowa
#   export ACCESS_TOKEN=$(gcloud auth print-access-token)  # or any OAuth2 access token with Firebase RC scope
#   ./scripts/publish_remote_config_rest.sh

PROJECT_ID=${PROJECT_ID:-talowa}
TEMPLATE=${TEMPLATE:-remoteconfig/rc.template.json}

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template $TEMPLATE not found" >&2
  exit 1
fi

: "${ACCESS_TOKEN:?Set ACCESS_TOKEN env var with a valid OAuth token}" 

curl -sS -X PUT \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json; UTF-8" \
  -H "If-Match: *" \
  --data-binary @"$TEMPLATE" \
  "https://firebaseremoteconfig.googleapis.com/v1/projects/$PROJECT_ID/remoteConfig" \
  -D /tmp/headers.txt -o /tmp/body.json

echo "Response headers:" && cat /tmp/headers.txt || true
echo "Response body:" && cat /tmp/body.json || true

if ! grep -i "etag:" /tmp/headers.txt >/dev/null; then
  echo "Publish may have failed; see logs above." >&2
  exit 1
fi

echo "Remote Config publish completed."

