#!/usr/bin/env bash
# Install pre-commit hook that blocks paid API key / SDK introduction.
# Run from skill root: ./scripts/install-hooks.sh
set -euo pipefail

skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$skill_root/.git/hooks/pre-commit"

if [ ! -d "$skill_root/.git" ]; then
  echo "ERROR: $skill_root is not a git repo. Run 'git init' first." >&2
  exit 1
fi

cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# Block any future commit that introduces paid API key usage or direct SDK imports.
# Policy: this skill must only call `claude` and `codex` CLIs (OAuth/subscription).
set -euo pipefail

forbidden_patterns=(
  'ANTHROPIC_API_KEY'
  'OPENAI_API_KEY'
  'import anthropic'
  'import openai'
  'from anthropic'
  'from openai'
  'api\.anthropic\.com'
  'api\.openai\.com'
  'anthropic\.Anthropic\('
)

# Files to scan: only staged additions/modifications, exclude docs that legitimately discuss the policy
staged=$(git diff --cached --name-only --diff-filter=AM | grep -vE '^(README\.md|SKILL\.md|\.git/hooks/|scripts/install-hooks\.sh)' || true)

if [ -z "$staged" ]; then
  exit 0
fi

violations=""
for f in $staged; do
  [ -f "$f" ] || continue
  for p in "${forbidden_patterns[@]}"; do
    matches=$(grep -nE "$p" "$f" || true)
    if [ -n "$matches" ]; then
      violations+="\n$f:\n$matches\n"
    fi
  done
done

if [ -n "$violations" ]; then
  echo "ERROR: pre-commit refused — paid API key usage or direct SDK import detected." >&2
  printf '%b' "$violations" >&2
  echo >&2
  echo "Policy: cmux-orchestrator must only use claude/codex CLIs (OAuth)." >&2
  exit 1
fi

exit 0
HOOK

chmod +x "$hook"
echo "Installed pre-commit hook at $hook"
