#!/usr/bin/env bash
# Usage: detect-stack.sh <project-dir>
# Emits a JSON stack descriptor and the chosen recipe to stdout.
set -euo pipefail
DIR="${1:-.}"
PKG="$DIR/package.json"

framework="unknown"; dbLayer="none"; testRunner="none"; monorepo="false"; locales="[]"

read_dep() { # key
  [ -f "$PKG" ] || { echo ""; return; }
  jq -r --arg k "$1" '((.dependencies // {}) + (.devDependencies // {}))[$k] // ""' "$PKG"
}

if [ -f "$PKG" ]; then
  [ -n "$(read_dep next)" ] && framework="nextjs"
  [ "$framework" = "unknown" ] && [ -n "$(read_dep vite)" ] && framework="vite"
  [ "$framework" = "unknown" ] && [ -n "$(read_dep @remix-run/react)" ] && framework="remix"
  [ "$framework" = "unknown" ] && [ -n "$(read_dep @sveltejs/kit)" ] && framework="sveltekit"
  [ -n "$(read_dep @supabase/supabase-js)" ] && dbLayer="supabase"
  [ "$dbLayer" = "none" ] && [ -n "$(read_dep @prisma/client)" ] && dbLayer="prisma"
  [ -n "$(read_dep vitest)" ] && testRunner="vitest"
  [ "$testRunner" = "none" ] && [ -n "$(read_dep jest)" ] && testRunner="jest"
  [ -n "$(read_dep next-intl)" ] && locales="\"detect-next-intl\""
  jq -e 'has("bin")' "$PKG" >/dev/null 2>&1 && [ "$framework" = "unknown" ] && framework="cli"
fi
{ [ -f "$DIR/pnpm-workspace.yaml" ] || jq -e 'has("workspaces")' "$PKG" >/dev/null 2>&1; } && monorepo="true" || true

# recipe selection
if [ "$framework" = "nextjs" ] && [ "$dbLayer" = "supabase" ]; then
  recipe="nextjs-supabase"
elif [ "$framework" = "nextjs" ] || [ "$framework" = "vite" ] || [ "$framework" = "remix" ] || [ "$framework" = "sveltekit" ]; then
  recipe="generic-web-playwright"
else
  recipe="_fallback"
fi

jq -nc \
  --arg framework "$framework" --arg dbLayer "$dbLayer" --arg testRunner "$testRunner" \
  --arg recipe "$recipe" --argjson monorepo "$monorepo" --argjson locales "$locales" \
  '{framework:$framework, dbLayer:$dbLayer, testRunner:$testRunner, monorepo:$monorepo, locales:$locales, recipe:$recipe}'
