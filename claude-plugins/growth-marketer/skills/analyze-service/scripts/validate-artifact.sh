#!/usr/bin/env bash
# Validate a produced artifact against its schema's x-required / x-required-item hints.
# Usage: validate-artifact.sh <schema-name> <artifact.json>
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: validate-artifact.sh <schema-name> <artifact.json>"
  exit 2
fi
SCHEMA_NAME="$1"
ARTIFACT="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="$ROOT/schemas/${SCHEMA_NAME}.schema.json"

[ -f "$SCHEMA" ]   || { echo "schema not found: $SCHEMA"; exit 2; }
[ -f "$ARTIFACT" ] || { echo "artifact file not found: $ARTIFACT"; exit 2; }
jq -e . "$ARTIFACT" >/dev/null 2>&1 || { echo "artifact is not valid JSON: $ARTIFACT"; exit 2; }
jq -e 'type == "object"' "$ARTIFACT" >/dev/null 2>&1 || { echo "artifact root must be a JSON object: $ARTIFACT"; exit 2; }

errors=0

# top-level required keys (schema .x-required)
while IFS= read -r key; do
  [ -z "$key" ] && continue
  if ! jq -e --arg k "$key" 'has($k) and (.[$k] != null)' "$ARTIFACT" >/dev/null; then
    echo "missing required field: $key"
    errors=$((errors+1))
  fi
done < <(jq -r '(."x-required" // [])[]' "$SCHEMA")

# nested object required keys (properties.<p>.x-required) — only checked if parent present
while IFS= read -r parent; do
  [ -z "$parent" ] && continue
  jq -e --arg p "$parent" 'has($p)' "$ARTIFACT" >/dev/null || continue
  while IFS= read -r sub; do
    [ -z "$sub" ] && continue
    if ! jq -e --arg p "$parent" --arg s "$sub" '.[$p] | (has($s) and (.[$s] != null))' "$ARTIFACT" >/dev/null; then
      echo "missing required field: ${parent}.${sub}"
      errors=$((errors+1))
    fi
  done < <(jq -r --arg p "$parent" '.properties[$p]."x-required" // [] | .[]' "$SCHEMA")
done < <(jq -r '.properties | to_entries[] | select(.value | has("x-required")) | .key' "$SCHEMA")

# array item required keys (properties.<p>.items.x-required-item)
while IFS= read -r arrkey; do
  [ -z "$arrkey" ] && continue
  jq -e --arg p "$arrkey" 'has($p)' "$ARTIFACT" >/dev/null || continue
  while IFS= read -r itemreq; do
    [ -z "$itemreq" ] && continue
    bad=$(jq --arg p "$arrkey" --arg r "$itemreq" '[.[$p][] | select((has($r) | not) or (.[$r] == null))] | length' "$ARTIFACT")
    if [ "$bad" != "0" ]; then
      echo "array '$arrkey' has $bad item(s) missing required field: $itemreq"
      errors=$((errors+1))
    fi
  done < <(jq -r --arg p "$arrkey" '.properties[$p].items."x-required-item" // [] | .[]' "$SCHEMA")
done < <(jq -r '.properties | to_entries[] | select(.value.items | type=="object" and has("x-required-item")) | .key' "$SCHEMA")

if [ "$errors" -gt 0 ]; then
  echo "FAIL: $errors contract violation(s) in $ARTIFACT"
  exit 1
fi
echo "OK: $ARTIFACT conforms to $SCHEMA_NAME"
