#!/usr/bin/env bash
# Usage: scaffold.sh --recipe <name> --target <dir> [--var k=v ...]
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SELF_DIR")"

RECIPE=""; TARGET=""; declare -A VARS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --recipe) RECIPE="$2"; shift 2;;
    --target) TARGET="$2"; shift 2;;
    --var) k="${2%%=*}"; v="${2#*=}"; VARS["$k"]="$v"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
[ -n "$RECIPE" ] && [ -n "$TARGET" ] || { echo "need --recipe and --target" >&2; exit 2; }

TPL_DIR="$SKILL_DIR/recipes/templates/$RECIPE"
[ -d "$TPL_DIR" ] || { echo "no templates for recipe $RECIPE" >&2; exit 3; }

# defaults
: "${VARS[port]:=3100}"
: "${VARS[locales]:=ko,en}"

render() { # file
  local out="$1"
  while IFS= read -r line || [ -n "$line" ]; do
    for k in "${!VARS[@]}"; do line="${line//\{\{$k\}\}/${VARS[$k]}}"; done
    printf '%s\n' "$line"
  done < "$out"
}

find "$TPL_DIR" -type f | while read -r tpl; do
  rel="${tpl#$TPL_DIR/}"; rel="${rel%.tpl}"
  dest="$TARGET/$rel"
  mkdir -p "$(dirname "$dest")"
  render "$tpl" > "$dest"
done
echo "scaffolded $RECIPE -> $TARGET"
