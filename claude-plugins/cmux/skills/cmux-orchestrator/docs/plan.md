# cmux-orchestrator Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** cmux 워크스페이스 위에서 Claude Code와 Codex 세션을 역할별 페인으로 자동 오케스트레이션하는 skill 1식을 만든다 (`~/.claude/skills/cmux-orchestrator/`).

**Architecture:** 단일 skill, progressive disclosure. SKILL.md(워크플로우 트리) + scripts/(bash 헬퍼, bats 단위 테스트) + references/(페인용 가이드 + 역할 본문 + orchestrator 정책) + commands/(슬래시) + evals/. manifest.json 이 single source of truth.

**Tech Stack:** bash + jq + bats(테스트) + cmux CLI + claude CLI + codex CLI + Playwright(스크린샷) + Figma MCP(design pane). 외부 의존성: macOS, cmux.app 설치, claude/codex 로그인 완료.

**Spec:** `docs/superpowers/specs/2026-04-29-cmux-orchestrator-design.md`

**Skill 작업 위치:** `~/.claude/skills/cmux-orchestrator/` (글로벌). 본 plan 의 모든 경로는 이 디렉토리 기준 상대 경로.

**Git 정책:** 본 skill 디렉토리 자체는 git 추적이 아님 (`~/.claude/skills/`는 사용자 home). 단, 작업 단위로 디스크 스냅샷을 위해 skill 디렉토리에 별도 git init 후 커밋. 향후 사용자가 별도 레포로 push 가능.

---

## Phase 0: Bootstrap

### Task 0.1: Skill 디렉토리 초기화

**Files:**

- Create: `~/.claude/skills/cmux-orchestrator/`
- Create: `~/.claude/skills/cmux-orchestrator/.gitignore`
- Create: `~/.claude/skills/cmux-orchestrator/README.md` (placeholder)
- Create: `~/.claude/skills/cmux-orchestrator/SKILL.md` (frontmatter only)

- [ ] **Step 1: 디렉토리 구조 만들기**

```bash
cd ~/.claude/skills
mkdir -p cmux-orchestrator/{commands,scripts,references/pane-roles,evals,tests/scripts,tests/fixtures}
cd cmux-orchestrator
```

- [ ] **Step 2: .gitignore 작성**

`.gitignore`:

```
.DS_Store
*.swp
node_modules/
```

- [ ] **Step 3: SKILL.md frontmatter 만 작성 (본문은 Phase 8에서)**

`SKILL.md`:

```markdown
---
name: cmux-orchestrator
description: |
  cmux 멀티페인 터미널 위에서 Claude Code와 Codex 세션을 역할별 페인(plan / design /
  test-scenario / test-code / dev / review)으로 자동 오케스트레이션해 한 작업을 끝까지
  처리한다. 사용자가 "여러 페인 띄워서 만들어", "멀티 에이전트로", "오케스트레이션",
  "claude 와 codex 같이", "plan-dev-review 분리해서", "여러 역할로 나눠서 작업해줘",
  "feature 자동 개발", "병렬로 여러 agent" 같은 표현을 쓸 때 반드시 발동한다.
  단순 한 파일 편집이나 한 번의 자문에는 발동하지 말 것 — multi-step 구현 작업에서만.
  Figma 디자인 일치도 검증, RED 테스트 작성 후 GREEN 구현, AC 기반 단계별 검증을
  모두 포함하는 풀 파이프라인이다.
---

(본문은 후속 Phase 에서 채움)
```

- [ ] **Step 4: README.md placeholder**

`README.md`:

```markdown
# cmux-orchestrator

cmux 워크스페이스 위에서 Claude Code 와 Codex 를 역할별 페인으로 오케스트레이션하는 skill.

(상세 사용법은 Phase 9 에서 작성)
```

- [ ] **Step 5: git init + 초기 커밋**

```bash
cd ~/.claude/skills/cmux-orchestrator
git init
git add .
git commit -m "chore: bootstrap cmux-orchestrator skill skeleton"
```

---

## Phase 1: Manifest helper (`scripts/manifest.sh`)

manifest.json 의 모든 읽기/쓰기를 한 곳에 모은 헬퍼. jq 의존. orchestrator 와 페인 양쪽에서 호출.

**Files:**

- Create: `scripts/manifest.sh`
- Create: `tests/scripts/test_manifest.bats`
- Create: `tests/fixtures/manifest_initial.json`

### Task 1.1: bats 테스트 부트스트랩 + `manifest_init`

- [ ] **Step 1: 테스트 파일 헤더 작성**

`tests/scripts/test_manifest.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export MANIFEST_PATH="$TMPDIR/manifest.json"
  source "$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "manifest_init creates valid JSON with required top-level fields" {
  manifest_init "feature-x" "test description" "claude"
  [ -f "$MANIFEST_PATH" ]
  run jq -r '.feature_slug' "$MANIFEST_PATH"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-x" ]
  run jq -r '.task_description' "$MANIFEST_PATH"
  [ "$output" = "test description" ]
  run jq -r '.schema_version' "$MANIFEST_PATH"
  [ "$output" = "1" ]
  run jq -r '.status' "$MANIFEST_PATH"
  [ "$output" = "in_progress" ]
}

@test "manifest_init initializes empty stages and panes" {
  manifest_init "feature-x" "desc" "claude"
  run jq -r '.stages | type' "$MANIFEST_PATH"
  [ "$output" = "object" ]
  run jq -r '.panes | type' "$MANIFEST_PATH"
  [ "$output" = "object" ]
  run jq -r '.acceptance_criteria | length' "$MANIFEST_PATH"
  [ "$output" = "0" ]
}
```

- [ ] **Step 2: 테스트 실행해서 fail 확인**

```bash
cd ~/.claude/skills/cmux-orchestrator
bats tests/scripts/test_manifest.bats
```

Expected: FAIL ("scripts/manifest.sh: No such file" 또는 함수 미정의)

- [ ] **Step 3: `scripts/manifest.sh` 헤더 + `manifest_init` 구현**

`scripts/manifest.sh`:

```bash
#!/usr/bin/env bash
# manifest.sh — cmux-orchestrator 의 manifest.json 헬퍼
# 모든 함수는 환경변수 MANIFEST_PATH 를 읽음
set -euo pipefail

manifest_init() {
  local slug="$1"
  local description="$2"
  local orchestrator_model="${3:-claude}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -n \
    --arg slug "$slug" \
    --arg desc "$description" \
    --arg now "$now" \
    --arg model "$orchestrator_model" \
    '{
      schema_version: 1,
      feature_slug: $slug,
      task_description: $desc,
      task_classification: "unknown",
      started_at: $now,
      last_updated: $now,
      status: "in_progress",
      workspace_id: null,
      visualization_command: null,
      orchestrator_model: $model,
      panes: {},
      acceptance_criteria: [],
      stages: {},
      design_verification: null
    }' > "$MANIFEST_PATH"
}
```

- [ ] **Step 4: 테스트 재실행**

```bash
bats tests/scripts/test_manifest.bats
```

Expected: 두 테스트 모두 PASS.

- [ ] **Step 5: commit**

```bash
git add scripts/manifest.sh tests/scripts/test_manifest.bats
git commit -m "feat(scripts): add manifest_init"
```

### Task 1.2: `manifest_set_stage`

stage 의 status / artifact / pane_ref 등 부분 업데이트.

- [ ] **Step 1: bats 테스트 추가**

`tests/scripts/test_manifest.bats` 끝에 append:

```bash
@test "manifest_set_stage creates stage when absent and updates fields" {
  manifest_init "f" "d" "claude"
  manifest_set_stage "plan" "status=running" "pane_ref=surface:5" "artifact=01-plan.md"
  run jq -r '.stages.plan.status' "$MANIFEST_PATH"
  [ "$output" = "running" ]
  run jq -r '.stages.plan.pane_ref' "$MANIFEST_PATH"
  [ "$output" = "surface:5" ]
  run jq -r '.stages.plan.artifact' "$MANIFEST_PATH"
  [ "$output" = "01-plan.md" ]
}

@test "manifest_set_stage merges into existing stage" {
  manifest_init "f" "d" "claude"
  manifest_set_stage "plan" "status=running"
  manifest_set_stage "plan" "status=done"
  run jq -r '.stages.plan.status' "$MANIFEST_PATH"
  [ "$output" = "done" ]
}

@test "manifest_set_stage updates last_updated timestamp" {
  manifest_init "f" "d" "claude"
  local before
  before=$(jq -r '.last_updated' "$MANIFEST_PATH")
  sleep 1
  manifest_set_stage "plan" "status=running"
  local after
  after=$(jq -r '.last_updated' "$MANIFEST_PATH")
  [ "$after" != "$before" ]
}
```

- [ ] **Step 2: 테스트 실행 fail 확인**

```bash
bats tests/scripts/test_manifest.bats
```

Expected: 새 3개 fail.

- [ ] **Step 3: `manifest_set_stage` 구현**

`scripts/manifest.sh` 끝에 append:

```bash
manifest_set_stage() {
  local stage="$1"
  shift
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp
  tmp="$(mktemp)"
  local jq_filter='.stages[$stage] = (.stages[$stage] // {}) | .last_updated = $now'
  jq --arg stage "$stage" --arg now "$now" "$jq_filter" "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
  for kv in "$@"; do
    local key="${kv%%=*}"
    local value="${kv#*=}"
    jq --arg stage "$stage" --arg key "$key" --arg val "$value" \
      '.stages[$stage][$key] = $val' "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
  done
}
```

- [ ] **Step 4: 테스트 재실행**

```bash
bats tests/scripts/test_manifest.bats
```

Expected: 모두 PASS.

- [ ] **Step 5: commit**

```bash
git add scripts/manifest.sh tests/scripts/test_manifest.bats
git commit -m "feat(scripts): add manifest_set_stage with merge semantics"
```

### Task 1.3: `manifest_get_stage_field` 와 `manifest_list_stages_by_status`

읽기 헬퍼 — 어디까지 done 인지 확인용.

- [ ] **Step 1: bats 테스트 추가**

```bash
@test "manifest_get_stage_field returns field value or empty" {
  manifest_init "f" "d" "claude"
  manifest_set_stage "plan" "status=done"
  run manifest_get_stage_field "plan" "status"
  [ "$output" = "done" ]
  run manifest_get_stage_field "design" "status"
  [ -z "$output" ]
}

@test "manifest_list_stages_by_status returns space-separated stage names" {
  manifest_init "f" "d" "claude"
  manifest_set_stage "plan" "status=done"
  manifest_set_stage "design" "status=running"
  manifest_set_stage "test-code" "status=done"
  run manifest_list_stages_by_status "done"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "plan"
  echo "$output" | grep -q "test-code"
  [ "$(echo "$output" | wc -w | tr -d ' ')" = "2" ]
}
```

- [ ] **Step 2: fail 확인**

```bash
bats tests/scripts/test_manifest.bats
```

- [ ] **Step 3: 구현**

`scripts/manifest.sh` 끝에 append:

```bash
manifest_get_stage_field() {
  local stage="$1"
  local field="$2"
  jq -r --arg s "$stage" --arg f "$field" '.stages[$s][$f] // ""' "$MANIFEST_PATH"
}

manifest_list_stages_by_status() {
  local status="$1"
  jq -r --arg s "$status" \
    '.stages | to_entries | map(select(.value.status == $s)) | map(.key) | .[]' \
    "$MANIFEST_PATH" | tr '\n' ' '
}
```

- [ ] **Step 4: 테스트 재실행**

```bash
bats tests/scripts/test_manifest.bats
```

Expected: PASS.

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add manifest read helpers"
```

### Task 1.4: `manifest_record_pane` 와 `manifest_pane_for_role`

페인 등록 + 역할로 surface ref 찾기.

- [ ] **Step 1: bats 테스트 추가**

```bash
@test "manifest_record_pane stores pane info under surface ref" {
  manifest_init "f" "d" "claude"
  manifest_record_pane "surface:5" "plan" "claude" "persistent"
  run jq -r '.panes."surface:5".role' "$MANIFEST_PATH"
  [ "$output" = "plan" ]
  run jq -r '.panes."surface:5".model' "$MANIFEST_PATH"
  [ "$output" = "claude" ]
  run jq -r '.panes."surface:5".lifecycle' "$MANIFEST_PATH"
  [ "$output" = "persistent" ]
  run jq -r '.panes."surface:5".alive' "$MANIFEST_PATH"
  [ "$output" = "true" ]
}

@test "manifest_pane_for_role returns surface ref of matching live pane" {
  manifest_init "f" "d" "claude"
  manifest_record_pane "surface:5" "plan" "claude" "persistent"
  manifest_record_pane "surface:6" "dev" "codex" "task-scoped"
  run manifest_pane_for_role "plan"
  [ "$output" = "surface:5" ]
  run manifest_pane_for_role "dev"
  [ "$output" = "surface:6" ]
  run manifest_pane_for_role "review"
  [ -z "$output" ]
}
```

- [ ] **Step 2: fail 확인**

```bash
bats tests/scripts/test_manifest.bats
```

- [ ] **Step 3: 구현**

`scripts/manifest.sh` 끝에 append:

```bash
manifest_record_pane() {
  local surface_ref="$1"
  local role="$2"
  local model="$3"
  local lifecycle="$4"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp
  tmp="$(mktemp)"
  jq --arg ref "$surface_ref" --arg role "$role" --arg model "$model" \
     --arg lifecycle "$lifecycle" --arg now "$now" \
    '.panes[$ref] = {
      role: $role,
      model: $model,
      lifecycle: $lifecycle,
      spawned_at: $now,
      alive_check_at: $now,
      alive: true
    } | .last_updated = $now' "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
}

manifest_pane_for_role() {
  local role="$1"
  jq -r --arg role "$role" \
    '.panes | to_entries | map(select(.value.role == $role and .value.alive == true)) | (.[0].key // "")' \
    "$MANIFEST_PATH"
}
```

- [ ] **Step 4: 테스트 재실행**

```bash
bats tests/scripts/test_manifest.bats
```

Expected: PASS.

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add manifest pane helpers"
```

### Task 1.5: `manifest_set_acceptance_criteria` 와 `manifest_set_classification`

plan 단계 결과 기록.

- [ ] **Step 1: bats 테스트 추가**

```bash
@test "manifest_set_classification updates task_classification" {
  manifest_init "f" "d" "claude"
  manifest_set_classification "new-feature-with-ui"
  run jq -r '.task_classification' "$MANIFEST_PATH"
  [ "$output" = "new-feature-with-ui" ]
}

@test "manifest_set_acceptance_criteria stores AC list from JSON file" {
  manifest_init "f" "d" "claude"
  cat > "$TMPDIR/ac.json" <<'EOF'
[
  { "id": "AC-1", "text": "POST returns 200", "verified_by": ["test-code","dev"] },
  { "id": "AC-2", "text": "duplicate -> 409", "verified_by": ["test-code"] }
]
EOF
  manifest_set_acceptance_criteria "$TMPDIR/ac.json"
  run jq -r '.acceptance_criteria | length' "$MANIFEST_PATH"
  [ "$output" = "2" ]
  run jq -r '.acceptance_criteria[0].id' "$MANIFEST_PATH"
  [ "$output" = "AC-1" ]
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

```bash
manifest_set_classification() {
  local classification="$1"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp
  tmp="$(mktemp)"
  jq --arg c "$classification" --arg now "$now" \
    '.task_classification = $c | .last_updated = $now' \
    "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
}

manifest_set_acceptance_criteria() {
  local json_file="$1"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp
  tmp="$(mktemp)"
  jq --slurpfile ac "$json_file" --arg now "$now" \
    '.acceptance_criteria = $ac[0] | .last_updated = $now' \
    "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
}
```

- [ ] **Step 4: 테스트 재실행 → PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add classification + AC helpers"
```

---

## Phase 2: Pane status 판정 (`scripts/pane-status.sh`)

cmux capture 출력을 읽어서 idle/working/dead/특수 신호를 판정. orchestrator 의 polling 루프에서 호출.

**Files:**

- Create: `scripts/pane-status.sh`
- Create: `tests/scripts/test_pane_status.bats`
- Create: `tests/fixtures/capture_claude_idle.txt`
- Create: `tests/fixtures/capture_claude_working.txt`
- Create: `tests/fixtures/capture_codex_idle.txt`
- Create: `tests/fixtures/capture_dead.txt`
- Create: `tests/fixtures/capture_rate_limit.txt`
- Create: `tests/fixtures/capture_billing.txt`

### Task 2.1: capture fixture 만들기

- [ ] **Step 1: claude idle fixture**

`tests/fixtures/capture_claude_idle.txt`:

```
이 작업을 완료했습니다.

산출물: 01-plan.md
plan done

────────────────────────────────────────
❯
────────────────────────────────────────
claude opus 4.7  ·  ~/Documents/dev/qplace
```

- [ ] **Step 2: claude working fixture**

`tests/fixtures/capture_claude_working.txt`:

```
파일을 분석 중입니다...

▶ Reading src/foo.ts
▶ 토큰 분석
```

- [ ] **Step 3: codex idle fixture**

`tests/fixtures/capture_codex_idle.txt`:

```
완료했습니다.

›
gpt-5.5  ·  ~/Documents/dev/qplace
```

- [ ] **Step 4: dead fixture (단순 shell)**

`tests/fixtures/capture_dead.txt`:

```
$ ls
package.json  src
$
```

- [ ] **Step 5: rate limit / billing fixtures**

`tests/fixtures/capture_rate_limit.txt`:

```
Error: rate limit exceeded. Try again in 45 seconds.
```

`tests/fixtures/capture_billing.txt`:

```
Error: billing credit exceeded for this period.
```

- [ ] **Step 6: commit**

```bash
git add tests/fixtures/
git commit -m "test(scripts): add pane capture fixtures"
```

### Task 2.2: `detect_footer_type`

- [ ] **Step 1: bats 테스트**

`tests/scripts/test_pane_status.bats`:

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../scripts/pane-status.sh"
  FIXTURES="$BATS_TEST_DIRNAME/../fixtures"
}

@test "detect_footer_type recognizes claude footer" {
  run detect_footer_type "$(cat $FIXTURES/capture_claude_idle.txt)"
  [ "$output" = "claude" ]
}

@test "detect_footer_type recognizes codex footer" {
  run detect_footer_type "$(cat $FIXTURES/capture_codex_idle.txt)"
  [ "$output" = "codex" ]
}

@test "detect_footer_type returns none on shell capture" {
  run detect_footer_type "$(cat $FIXTURES/capture_dead.txt)"
  [ "$output" = "none" ]
}
```

- [ ] **Step 2: fail 확인**

```bash
bats tests/scripts/test_pane_status.bats
```

- [ ] **Step 3: 구현**

`scripts/pane-status.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# detect_footer_type <capture_text>
# claude / codex / none
detect_footer_type() {
  local capture="$1"
  if echo "$capture" | grep -qE 'claude (opus|sonnet|haiku) [0-9]'; then
    echo "claude"
    return
  fi
  if echo "$capture" | grep -qE 'gpt-[0-9](\.[0-9])?'; then
    echo "codex"
    return
  fi
  echo "none"
}
```

- [ ] **Step 4: 테스트 재실행 PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add detect_footer_type"
```

### Task 2.3: `detect_failure_signal`

rate limit / billing / 일반 error 매칭.

- [ ] **Step 1: bats 테스트 추가**

```bash
@test "detect_failure_signal returns rate-limit and parses wait seconds" {
  result=$(detect_failure_signal "$(cat $FIXTURES/capture_rate_limit.txt)")
  echo "$result" | grep -q "kind=rate_limit"
  echo "$result" | grep -q "wait_seconds=45"
}

@test "detect_failure_signal returns billing for billing keyword" {
  result=$(detect_failure_signal "$(cat $FIXTURES/capture_billing.txt)")
  echo "$result" | grep -q "kind=billing"
}

@test "detect_failure_signal returns none on healthy capture" {
  result=$(detect_failure_signal "$(cat $FIXTURES/capture_claude_idle.txt)")
  [ "$result" = "kind=none" ]
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

`scripts/pane-status.sh` 끝에 append:

```bash
# detect_failure_signal <capture>
# echoes "kind=<rate_limit|billing|none>" and optional "wait_seconds=<n>"
detect_failure_signal() {
  local capture="$1"
  if echo "$capture" | grep -qiE 'rate.?limit|429'; then
    local wait_s
    wait_s="$(echo "$capture" | grep -oiE 'try again in ([0-9]+)' | head -1 | grep -oE '[0-9]+' || true)"
    if [ -n "$wait_s" ]; then
      echo "kind=rate_limit wait_seconds=$wait_s"
    else
      echo "kind=rate_limit"
    fi
    return
  fi
  if echo "$capture" | grep -qiE 'billing|credit (exceeded|exhausted)'; then
    echo "kind=billing"
    return
  fi
  echo "kind=none"
}
```

- [ ] **Step 4: 테스트 PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add detect_failure_signal"
```

### Task 2.4: `is_pane_idle` (capture 동일 + 모델 footer)

- [ ] **Step 1: bats 테스트 추가**

```bash
@test "is_pane_idle returns 0 when two consecutive captures match and footer present" {
  local cap
  cap="$(cat $FIXTURES/capture_claude_idle.txt)"
  run is_pane_idle "$cap" "$cap"
  [ "$status" -eq 0 ]
}

@test "is_pane_idle returns non-zero when captures differ" {
  local a b
  a="$(cat $FIXTURES/capture_claude_idle.txt)"
  b="$(cat $FIXTURES/capture_claude_working.txt)"
  run is_pane_idle "$a" "$b"
  [ "$status" -ne 0 ]
}

@test "is_pane_idle returns non-zero when footer absent" {
  local cap
  cap="$(cat $FIXTURES/capture_dead.txt)"
  run is_pane_idle "$cap" "$cap"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

```bash
# is_pane_idle <prev_capture> <current_capture>
# exit 0 = idle, non-zero = working/dead
is_pane_idle() {
  local prev="$1"
  local curr="$2"
  [ "$prev" = "$curr" ] || return 1
  local footer
  footer="$(detect_footer_type "$curr")"
  [ "$footer" != "none" ] || return 2
}
```

- [ ] **Step 4: PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add is_pane_idle"
```

### Task 2.5: `is_pane_dead`

footer 없음 + 동일 capture → dead. (working 과 구분: working 은 footer 없어도 capture 변동)

- [ ] **Step 1: bats 테스트 추가**

```bash
@test "is_pane_dead returns 0 when no footer and identical captures" {
  local cap
  cap="$(cat $FIXTURES/capture_dead.txt)"
  run is_pane_dead "$cap" "$cap"
  [ "$status" -eq 0 ]
}

@test "is_pane_dead returns non-zero when footer present" {
  local cap
  cap="$(cat $FIXTURES/capture_claude_idle.txt)"
  run is_pane_dead "$cap" "$cap"
  [ "$status" -ne 0 ]
}

@test "is_pane_dead returns non-zero when captures differ (still working)" {
  local a b
  a="$(cat $FIXTURES/capture_claude_working.txt)"
  b="$(cat $FIXTURES/capture_claude_idle.txt)"
  run is_pane_dead "$a" "$b"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

```bash
# is_pane_dead <prev> <curr>
is_pane_dead() {
  local prev="$1"
  local curr="$2"
  [ "$prev" = "$curr" ] || return 1
  local footer
  footer="$(detect_footer_type "$curr")"
  [ "$footer" = "none" ] || return 2
}
```

- [ ] **Step 4: PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add is_pane_dead"
```

### Task 2.6: `extract_context_percent` (model footer token% 추출)

claude footer 의 `(15% used)` 같은 표시 추출. claude/codex 둘 다 footer 형식이 진화 중이라 보수적으로: 추출 실패 시 0 반환 (compact-or-fork 가 알아서 0 = 임계 미도달로 처리).

- [ ] **Step 1: 추가 fixture**

`tests/fixtures/capture_claude_high_ctx.txt`:

```
이전 컨텍스트가 많습니다.

❯
claude opus 4.7  ·  ~/repo  ·  72% context used
```

- [ ] **Step 2: bats 테스트 추가**

```bash
@test "extract_context_percent reads value from claude footer" {
  run extract_context_percent "$(cat $FIXTURES/capture_claude_high_ctx.txt)"
  [ "$output" = "72" ]
}

@test "extract_context_percent returns 0 when no percent visible" {
  run extract_context_percent "$(cat $FIXTURES/capture_claude_idle.txt)"
  [ "$output" = "0" ]
}
```

- [ ] **Step 3: 구현**

```bash
# extract_context_percent <capture>
# echoes 0..100 (0 if not found)
extract_context_percent() {
  local capture="$1"
  local pct
  pct="$(echo "$capture" | grep -oiE '([0-9]{1,3})% (context )?(used|of context)' | head -1 | grep -oE '^[0-9]+' || true)"
  echo "${pct:-0}"
}
```

- [ ] **Step 4: PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add extract_context_percent"
```

---

## Phase 3: Send-and-poll (`scripts/send-and-poll.sh`)

cmux send + Enter + idle polling. cmux-pane-chat skill 의 잘 알려진 함정 (send-key Enter 빼먹기) 을 회피.

**Files:**

- Create: `scripts/send-and-poll.sh`
- Create: `tests/scripts/test_send_and_poll.bats`

cmux 호출 자체는 mock 하기 어려워 두 함수만 단위 테스트:

- `send_text_with_enter`: cmux 명령 합성만 검증 (실제 cmux 안 부름, `CMUX_BIN` env override)
- `poll_until_idle`: capture 함수를 인자로 받아 mock 가능

### Task 3.1: `send_text_with_enter`

- [ ] **Step 1: bats 테스트**

`tests/scripts/test_send_and_poll.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export CMUX_LOG="$TMPDIR/cmux_calls.log"
  cat > "$TMPDIR/cmux" <<'SH'
#!/usr/bin/env bash
echo "$@" >> "$CMUX_LOG"
SH
  chmod +x "$TMPDIR/cmux"
  export CMUX_BIN="$TMPDIR/cmux"
  source "$BATS_TEST_DIRNAME/../../scripts/send-and-poll.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "send_text_with_enter calls send then send-key Enter" {
  send_text_with_enter "surface:5" "hello world"
  run cat "$CMUX_LOG"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "send --surface surface:5 hello world"
  echo "$output" | grep -q "send-key --surface surface:5 Enter"
}

@test "send_text_with_enter preserves newlines and quotes" {
  send_text_with_enter "surface:5" "line1
line2"
  run cat "$CMUX_LOG"
  echo "$output" | grep -q "send --surface surface:5"
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

`scripts/send-and-poll.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

CMUX_BIN="${CMUX_BIN:-cmux}"

# send_text_with_enter <surface_ref> <text>
# 함정 회피: send 만 보내면 입력만 들어가고 제출 안 됨
send_text_with_enter() {
  local surface="$1"
  shift
  local text="$*"
  "$CMUX_BIN" send --surface "$surface" "$text"
  "$CMUX_BIN" send-key --surface "$surface" Enter
}
```

- [ ] **Step 4: PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add send_text_with_enter"
```

### Task 3.2: `poll_until_idle` (capture provider mockable)

- [ ] **Step 1: bats 테스트**

```bash
@test "poll_until_idle exits 0 when two consecutive captures match (mock provider)" {
  cat > "$TMPDIR/capture_seq.txt" <<'EOF'
working...
working more...
done

❯
claude opus 4.7  ·  ~/repo
done

❯
claude opus 4.7  ·  ~/repo
EOF
  capture_provider() {
    local n
    n=$(cat "$TMPDIR/poll_idx" 2>/dev/null || echo 0)
    awk -v section=$((n+1)) 'BEGIN{RS=""} NR==section' "$TMPDIR/capture_seq.txt"
    echo $((n+1)) > "$TMPDIR/poll_idx"
  }
  export -f capture_provider
  run poll_until_idle capture_provider 0 5
  [ "$status" -eq 0 ]
}

@test "poll_until_idle exits non-zero on max iterations" {
  capture_provider() { echo "still working $(date +%N)"; }
  export -f capture_provider
  run poll_until_idle capture_provider 0 3
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

`scripts/send-and-poll.sh` 끝에 append:

```bash
# poll_until_idle <capture_provider_fn> <sleep_seconds> <max_iters>
# capture_provider_fn 는 매 호출마다 capture 텍스트를 stdout 으로
poll_until_idle() {
  local provider_fn="$1"
  local sleep_s="${2:-3}"
  local max_iters="${3:-20}"
  local prev=""
  local i=0
  while [ "$i" -lt "$max_iters" ]; do
    [ "$sleep_s" -gt 0 ] && sleep "$sleep_s"
    local curr
    curr="$("$provider_fn")"
    if [ -n "$prev" ] && [ "$prev" = "$curr" ]; then
      # idle 또는 dead — caller 가 추가 판정
      echo "$curr"
      return 0
    fi
    prev="$curr"
    i=$((i + 1))
  done
  echo "$prev" >&2
  return 1
}
```

- [ ] **Step 4: PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add poll_until_idle with provider injection"
```

### Task 3.3: `cmux_capture` (얇은 wrapper)

cmux capture-pane 호출. 단위 테스트는 mock cmux 만 검증.

- [ ] **Step 1: bats 테스트**

```bash
@test "cmux_capture invokes cmux capture-pane with surface and lines" {
  cmux_capture "surface:5" 60 > /dev/null
  run cat "$CMUX_LOG"
  echo "$output" | grep -q "capture-pane --surface surface:5 --lines 60"
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

```bash
# cmux_capture <surface_ref> [lines]
cmux_capture() {
  local surface="$1"
  local lines="${2:-60}"
  "$CMUX_BIN" capture-pane --surface "$surface" --lines "$lines"
}
```

- [ ] **Step 4: PASS**

- [ ] **Step 5: commit**

```bash
git add -u
git commit -m "feat(scripts): add cmux_capture wrapper"
```

---

## Phase 4: Compact-or-fork (`scripts/compact-or-fork.sh`)

토큰 임계 도달 시 `/compact` 전송 또는 페인 fork 결정.

**Files:**

- Create: `scripts/compact-or-fork.sh`
- Create: `tests/scripts/test_compact_or_fork.bats`

### Task 4.1: `decide_action` (60% / 85% 분기)

- [ ] **Step 1: bats 테스트**

`tests/scripts/test_compact_or_fork.bats`:

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../scripts/compact-or-fork.sh"
}

@test "decide_action returns none below 60%" {
  run decide_action 45 "persistent"
  [ "$output" = "none" ]
}

@test "decide_action returns compact at 60-84% on persistent pane" {
  run decide_action 70 "persistent"
  [ "$output" = "compact" ]
}

@test "decide_action returns fork at >=85% on persistent pane" {
  run decide_action 90 "persistent"
  [ "$output" = "fork" ]
}

@test "decide_action returns fork instead of compact for task-scoped pane" {
  # task-scoped 페인은 어차피 곧 닫힘 → compact 의미 없음, 한도 도달 시 fork 또는 abort
  run decide_action 70 "task-scoped"
  [ "$output" = "fork" ]
}
```

- [ ] **Step 2: fail 확인**

- [ ] **Step 3: 구현**

`scripts/compact-or-fork.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# decide_action <context_percent> <lifecycle>
# echoes one of: none / compact / fork
decide_action() {
  local pct="$1"
  local lifecycle="$2"
  if [ "$pct" -lt 60 ]; then
    echo "none"
    return
  fi
  if [ "$pct" -ge 85 ]; then
    echo "fork"
    return
  fi
  if [ "$lifecycle" = "persistent" ]; then
    echo "compact"
    return
  fi
  echo "fork"
}
```

- [ ] **Step 4: PASS**

- [ ] **Step 5: commit**

```bash
git add scripts/compact-or-fork.sh tests/scripts/test_compact_or_fork.bats
git commit -m "feat(scripts): add compact-or-fork decision"
```

### Task 4.2: 통합 — `compact-or-fork.sh` 가 manifest+pane-status+send-and-poll 호출

이 함수는 통합 함수라 단위 테스트 어려움 → 인터페이스만 정의, dry-run 으로 검증.

- [ ] **Step 1: 인터페이스 명세 작성 (주석)**

`scripts/compact-or-fork.sh` 끝에 append:

```bash
# manage_context <surface_ref>
# - cmux_capture 로 현재 capture
# - extract_context_percent → pct
# - manifest 의 lifecycle 조회
# - decide_action(pct, lifecycle):
#   - none: 아무것도 안 함, exit 0
#   - compact: send_text_with_enter "$surface" "/compact"; exit 0 (재시도는 caller)
#   - fork: stderr 에 "fork:role=<role>:artifact=<path>" 출력; exit 10 (caller 가 새 spawn)
manage_context() {
  local surface="$1"
  source "$(dirname "$BASH_SOURCE")/pane-status.sh"
  source "$(dirname "$BASH_SOURCE")/send-and-poll.sh"
  source "$(dirname "$BASH_SOURCE")/manifest.sh"
  local cap pct lifecycle role artifact
  cap="$(cmux_capture "$surface" 80)"
  pct="$(extract_context_percent "$cap")"
  lifecycle="$(jq -r --arg s "$surface" '.panes[$s].lifecycle // ""' "$MANIFEST_PATH")"
  local action
  action="$(decide_action "$pct" "$lifecycle")"
  case "$action" in
    none) return 0 ;;
    compact) send_text_with_enter "$surface" "/compact"; return 0 ;;
    fork)
      role="$(jq -r --arg s "$surface" '.panes[$s].role // ""' "$MANIFEST_PATH")"
      artifact="$(jq -r --arg s "$surface" --arg role "$(jq -r --arg s "$surface" ".panes[\$s].role" "$MANIFEST_PATH")" '.stages[$role].artifact // ""' "$MANIFEST_PATH")"
      echo "fork:role=$role:artifact=$artifact" >&2
      return 10
      ;;
  esac
}
```

- [ ] **Step 2: 통합용 fixture-기반 smoke test (manifest+capture mock)**

`tests/scripts/test_compact_or_fork.bats` 끝에 append:

```bash
@test "manage_context calls /compact at 70% on persistent pane (mock cmux)" {
  TMPDIR=$(mktemp -d)
  export MANIFEST_PATH="$TMPDIR/manifest.json"
  export CMUX_LOG="$TMPDIR/cmux.log"
  cat > "$TMPDIR/cmux" <<SH
#!/usr/bin/env bash
case "\$1" in
  capture-pane)
    cat "$BATS_TEST_DIRNAME/../fixtures/capture_claude_high_ctx.txt"
    ;;
  *)
    echo "\$@" >> "$CMUX_LOG"
    ;;
esac
SH
  chmod +x "$TMPDIR/cmux"
  export CMUX_BIN="$TMPDIR/cmux"
  cat > "$MANIFEST_PATH" <<'EOF'
{ "panes": { "surface:5": { "role": "plan", "model": "claude", "lifecycle": "persistent" } }, "stages": {} }
EOF
  run manage_context "surface:5"
  [ "$status" -eq 0 ]
  run cat "$CMUX_LOG"
  echo "$output" | grep -q "send --surface surface:5 /compact"
  rm -rf "$TMPDIR"
}
```

- [ ] **Step 3: 테스트 실행 PASS**

```bash
bats tests/scripts/test_compact_or_fork.bats
```

- [ ] **Step 4: commit**

```bash
git add -u
git commit -m "feat(scripts): integrate manage_context"
```

---

## Phase 5: References — 페인용 가이드 (페인이 직접 읽음)

페인 부트스트랩 메시지에서 "\_guides/X.md 읽고 시작" 으로 가리키는 짧은 가이드들. orchestrator 가 workspace 부트스트랩 시 `references/` → `_guides/` 로 단순 복사.

**Files:**

- Create: `references/handoff-conventions.md`
- Create: `references/cross-pane-chat.md`
- Create: `references/self-verify.md`

### Task 5.1: `references/handoff-conventions.md`

manifest.json schema, 파일 명명, 갱신 규약. spec Section 8 + Section 4 기반.

- [ ] **Step 1: 작성**

`references/handoff-conventions.md`:

````markdown
# Handoff conventions

cmux-orchestrator 워크스페이스 안의 모든 페인이 따르는 산출물·매니페스트 규약.

## 디스크 구조

```
<repo>/.cmux-orchestrator/<feature_slug>/
├── manifest.json
├── _guides/                   (orchestrator 가 references/ 에서 복사한 가이드)
├── 01-plan.md
├── 02-design.md               (UI 작업 시)
├── 03-test-scenarios.md
├── 04-test-code.md
├── 05-dev.md
├── 06-review.md
├── 07-design-verify.md        (UI + dev 후)
└── screenshots/               (visual verify 시)
```

## 파일 명명 규칙

- `NN-<role>.md` — `01..06`. design-verify 만 `07-` (조건부).
- 모든 페인은 자기 산출물 파일 외에 `manifest.json` 만 갱신. 다른 페인의 산출물 수정 금지.

## manifest.json 갱신 규칙

- `scripts/manifest.sh` 헬퍼 사용 권장 (`MANIFEST_PATH` env 설정 후).
- 직접 jq 사용 시:
  - 항상 새 파일에 쓰고 `mv` 로 atomic 교체 (tmp file 패턴).
  - `last_updated` 필드를 매 변경마다 갱신.

## 산출물 schema

각 역할의 산출물 schema 는 페인 부트스트랩 메시지의 "역할 본문" 에 인라인됨. 본 가이드는 디스크 구조와 매니페스트만.

## 안전

- destructive 명령 (`rm -rf`, `git reset --hard`, 마이그레이션) 모든 페인에서 금지.
- 워크스페이스 디렉토리 (`.cmux-orchestrator/<slug>/`) 외부 쓰기 금지. 단:
  - dev pane 은 repo 본 코드 수정 허용 (변경 경로를 `05-dev.md` 에 기록).
  - test-code pane 은 `*.test.*` 파일만 수정.
````

- [ ] **Step 2: commit**

```bash
git add references/handoff-conventions.md
git commit -m "docs(references): add handoff-conventions"
```

### Task 5.2: `references/cross-pane-chat.md`

기존 `cmux-pane-chat` skill 을 페인 관점으로 압축.

- [ ] **Step 1: 작성**

`references/cross-pane-chat.md`:

````markdown
# Cross-pane chat (자문 채널)

당신이 다른 페인 (예: plan, dev, review) 에게 짧은 자문을 요청하거나 받을 때의 규약. orchestrator 가 부트스트랩 메시지에 surface ref 매핑을 같이 줬으니, 그 매핑대로 호출한다.

## 사용 케이스 (허용)

- 다른 페인이 산출한 결정의 근거 한 줄 질의
- 모호한 AC 의 해석 자문
- 본인이 작성한 산출물에 대한 sanity check 요청

## 사용 금지

- 다른 페인에 작업 위임 (각 페인 역할 분리)
- destructive 명령 요청
- 사용자 모르게 장기 대화

## 절차

1. 상대 페인이 작업 중인지 확인:

   ```bash
   cmux capture-pane --surface surface:N --lines 20
   ```

   capture 가 빠르게 변하면 작업 중. 끼어들지 말 것.

2. 대상이 idle 이면 메시지 전송 (반드시 본인이 누구인지 한 줄 식별):

   ```bash
   cmux send --surface surface:N "[from {your-role} pane] 짧은 질문 본문"
   cmux send-key --surface surface:N Enter
   ```

   `send-key Enter` 빼먹으면 입력만 들어가고 제출 안 됨.

3. 응답 폴링:

   ```bash
   prev=""
   for i in 1 2 3 4 5; do
     sleep 4
     cur=$(cmux capture-pane --surface surface:N --lines 60)
     [ "$cur" = "$prev" ] && break
     prev=$cur
   done
   echo "$cur"
   ```

4. 응답 본문에서 모델 footer 와 입력 프롬프트 라인 제외하고 본문만 읽음.

## 토큰 예산

자문 1회 = 보통 200~500 토큰. 자문이 4번 이상이면 작업 분담을 잘못한 것 — orchestrator 에게 한 줄 보고하고 흐름 재정비 요청.
````

- [ ] **Step 2: commit**

```bash
git add references/cross-pane-chat.md
git commit -m "docs(references): add cross-pane-chat"
```

### Task 5.3: `references/self-verify.md`

각 역할의 self-verify 체크리스트 표준. 페인이 작업 완료 시 본 가이드의 자기 섹션 읽고 manifest 에 결과 기록.

- [ ] **Step 1: 작성**

`references/self-verify.md`:

````markdown
# Self-verify checklists

각 페인은 작업 완료 시 본 가이드의 자기 역할 섹션을 실행하고 결과를 `manifest.json` 의 `stages.<role>.self_verified` 에 기록한다.

기록 형식:

```json
{
  "ok": true|false,
  "checklist": ["항목1: ✓", "항목2: ✓", "항목3: ✗ (이유)"],
  "evidence": "재현 가능한 명령 또는 출력 발췌"
}
```

`scripts/manifest.sh` 의 헬퍼:

```bash
source ~/.claude/skills/cmux-orchestrator/scripts/manifest.sh
# 직접 jq 도 가능 — atomic 교체만 지킬 것.
```

## [plan]

- [ ] AC ≥ 1
- [ ] 각 AC 가 명제 형식 ("X 한다" 가 아닌 "X 가 일어났을 때 Y 가 검증된다")
- [ ] task_classification 이 5 enum 중 하나 (`new-feature-no-ui` / `new-feature-with-ui` / `bugfix` / `refactor` / `design-only`)
- [ ] UI 분류면 figma_frame_urls ≥ 1 또는 명시적 "Figma 없음"

## [design]

A 단계 (plan 후):

- [ ] figma_frame_urls 가 비어있지 않음
- [ ] 컴포넌트 매핑 표 ≥ 1
- [ ] 토큰 매핑 표 ≥ 1
- [ ] 모든 figma frame 이 표에 1회 이상 등장

B 단계 (dev 후):

- [ ] 모든 UI 관련 AC 가 1개 이상 항목으로 다뤄짐
- [ ] match_status 가 `pass | partial | fail` 중 하나
- [ ] partial/fail 항목은 fix_hint 채워짐

## [test-scenario]

- [ ] 모든 AC 가 시나리오 ≥ 1 매핑
- [ ] 시나리오마다 입력 + 실행 + 기대 명시

## [test-code]

- [ ] 모든 시나리오 → 테스트 매핑
- [ ] 작성한 테스트를 즉시 실행해서 모두 RED 확인 (PASS 가 1개라도 있으면 fail)
- [ ] 실행 명령 04-test-code.md 에 기록 (재현 가능)

## [dev]

- [ ] 04-test-code.md 의 명령으로 테스트 실행 → 모두 GREEN
- [ ] `pnpm lint` 통과 (또는 프로젝트 lint 명령)
- [ ] 변경된 파일 list 가 05-dev.md 에 명시

## [review]

- [ ] 모든 AC 가 ✓/✗/N/A 중 하나로 표시
- [ ] 발견 이슈 0건이면 "통과" 한 줄 명시, 아니면 모든 이슈에 severity / path:line / suggestion
````

- [ ] **Step 2: commit**

```bash
git add references/self-verify.md
git commit -m "docs(references): add self-verify checklists"
```

---

## Phase 6: References — 역할별 본문 (`pane-roles/*.md`)

각 파일은 spec Section 7.2 의 schema 를 그대로 옮긴 것. orchestrator 가 페인 부트스트랩 메시지의 `{role_body}` 자리에 발췌해서 인라인.

**Files:**

- Create: `references/pane-roles/plan.md`
- Create: `references/pane-roles/design.md`
- Create: `references/pane-roles/test-scenario.md`
- Create: `references/pane-roles/test-code.md`
- Create: `references/pane-roles/dev.md`
- Create: `references/pane-roles/review.md`

### Task 6.1: `pane-roles/plan.md`

- [ ] **Step 1: 작성**

`references/pane-roles/plan.md`:

````markdown
# [plan] 역할 본문

당신의 임무는 사용자 task description 을 검증 가능한 AC 로 분해하는 것입니다.

## 입력

- 사용자 task description (orchestrator 가 부트스트랩 메시지에 같이 전달)

## 산출물 (`01-plan.md`) schema

```markdown
# Plan: {slug}

## 분류

new-feature-no-ui | new-feature-with-ui | bugfix | refactor | design-only

## Acceptance Criteria

- AC-1: <명제 형식. "X 한다" 가 아니라 "X 가 일어났을 때 Y 가 검증된다">
- AC-2: ...

## 제약

- ...

## 위험 / 가정

- ...

## (UI 있는 경우) 관련 Figma frames

- url1, url2...
```

## 중요한 차이

- 명제 형식 강제. 예:
  - 나쁨: "유저가 신청서를 제출할 수 있다" (행위)
  - 좋음: "POST /applications 200 응답 + DB row 1개 생성 + 동일 폼버전 중복 제출 시 409"

## self-verify

`_guides/self-verify.md` 의 [plan] 섹션 체크리스트 실행.
````

- [ ] **Step 2: commit**

```bash
git add references/pane-roles/plan.md
git commit -m "docs(pane-roles): plan"
```

### Task 6.2: `pane-roles/design.md`

- [ ] **Step 1: 작성**

`references/pane-roles/design.md`:

````markdown
# [design] 역할 본문

당신은 두 시점에 호출됩니다 — A: plan 후 Figma 분석, B: dev 후 일치도 검증.

## A 단계 산출물 (`02-design.md`) schema

```markdown
# Design: {slug}

## figma_frame_urls

- url1, url2...

## 컴포넌트 매핑

| figma 컴포넌트 | design-system 매핑           | 비고 |
| -------------- | ---------------------------- | ---- |
| Button/Primary | `<Button variant="primary">` |      |
| Input/Text     | `<TextField>`                |      |
| ...            | (없으면 "신규 필요" + 제안)  |      |

## 토큰 매핑

| 카테고리 | figma 값 | design-system 토큰 |
| -------- | -------- | ------------------ |
| color    | #1A56FF  | `color-brand`      |
| spacing  | 32px     | `gap-8`            |
```

## B 단계 산출물 (`07-design-verify.md`) schema

```markdown
# Design verify: {slug}

## AC 별 일치도

### AC-3: <text>

- Figma frame: <url>
- 구현 스크린샷: screenshots/<file>.png
- match_status: pass | partial | fail

#### Pass 항목

- ✓ 색상 (color-brand)
- ✓ 폰트 크기

#### Partial / Fail 항목

| type      | location | expected | actual | fix_hint           |
| --------- | -------- | -------- | ------ | ------------------ |
| spacing   | ...      | 32px     | 16px   | <path>:<line> mt-8 |
| component | ...      | ...      | ...    | size="lg" 누락     |
```

## Figma MCP 사용

Figma MCP 가 본 페인에 연결되어 있다 (orchestrator 가 spawn 시 보장). frame URL 로 fetch 하여 컴포넌트 트리 / 토큰 / spacing 추출.

## self-verify

`_guides/self-verify.md` 의 [design] 섹션. A 단계와 B 단계 체크리스트가 따로 있음.
````

- [ ] **Step 2: commit**

```bash
git add references/pane-roles/design.md
git commit -m "docs(pane-roles): design"
```

### Task 6.3: `pane-roles/test-scenario.md`

- [ ] **Step 1: 작성**

`references/pane-roles/test-scenario.md`:

````markdown
# [test-scenario] 역할 본문

당신의 임무는 plan 의 AC 를 검증 가능한 시나리오로 분해하는 것입니다.

## 입력

- `01-plan.md` (Acceptance Criteria 섹션)
- (UI 작업 시) `02-design.md`

## 산출물 (`03-test-scenarios.md`) schema

```markdown
# Test scenarios: {slug}

## AC-1: <text>

### S1: <간단 제목>

- 입력: ...
- 실행: ...
- 기대: ...

### S2: ...

## AC-2: ...
```

## self-verify

`_guides/self-verify.md` 의 [test-scenario] 섹션.
````

- [ ] **Step 2: commit**

```bash
git add references/pane-roles/test-scenario.md
git commit -m "docs(pane-roles): test-scenario"
```

### Task 6.4: `pane-roles/test-code.md`

- [ ] **Step 1: 작성**

`references/pane-roles/test-code.md`:

````markdown
# [test-code] 역할 본문

당신의 임무는 시나리오를 실패하는 (RED) 테스트로 변환하는 것입니다.

## 입력

- `03-test-scenarios.md`
- repo 의 기존 테스트 컨벤션 (vitest 사용 가정. 다른 프레임워크면 orchestrator 가 부트스트랩에 명시)

## 작업

1. 시나리오마다 테스트 케이스 작성
2. 즉시 실행: `pnpm test --run <path>`
3. 모두 RED 확인 (PASS 가 1개라도 있으면 dev 가 이미 구현되어 있다는 뜻 — orchestrator 에게 한 줄 보고)

## 산출물 (`04-test-code.md`) schema

```markdown
# Test code: {slug}

## 작성 파일

- `<path>`: 함수명 list

## 실행 명령

- `pnpm test --run <path>`

## RED 증거

(vitest 출력 발췌; "X failed, 0 passed")
```

## 제약

- 본 페인은 `*.test.ts` / `*.test.tsx` 만 수정. 본 코드 수정 금지 (dev pane 영역).

## self-verify

`_guides/self-verify.md` 의 [test-code] 섹션.
````

- [ ] **Step 2: commit**

```bash
git add references/pane-roles/test-code.md
git commit -m "docs(pane-roles): test-code"
```

### Task 6.5: `pane-roles/dev.md`

- [ ] **Step 1: 작성**

`references/pane-roles/dev.md`:

````markdown
# [dev] 역할 본문

당신의 임무는 plan + (design) + 시나리오 보고 구현하여 test-code 의 테스트를 모두 GREEN 으로 만드는 것입니다.

## 입력

- `01-plan.md`
- (UI 작업 시) `02-design.md`
- `03-test-scenarios.md`
- `04-test-code.md` (실행할 명령 + 작성된 테스트 파일)

## 작업

1. 본 코드 수정 (test-code pane 이 동시 편집 중일 수 있으니 `*.test.*` 는 만지지 말 것)
2. `pnpm test --run <paths>` → GREEN 확인
3. `pnpm lint` → 통과
4. 변경된 파일과 결정 로그를 `05-dev.md` 에 기록

## 산출물 (`05-dev.md`) schema

```markdown
# Dev: {slug}

## 변경 파일

- <path>

## 결정 로그

- "X 대신 Y 선택, 이유: Z"

## self-verify

### 테스트

(pnpm test --run <paths> 출력; "X passed, 0 failed")

### lint

(pnpm lint 출력; clean)
```

## 제약

- destructive 명령 금지 (마이그레이션/git reset --hard/rm -rf 등)
- 본인 검증 끝나기 전에 commit 하지 말 것 (orchestrator 가 통합 검증 후 결정)

## self-verify

`_guides/self-verify.md` 의 [dev] 섹션.
````

- [ ] **Step 2: commit**

```bash
git add references/pane-roles/dev.md
git commit -m "docs(pane-roles): dev"
```

### Task 6.6: `pane-roles/review.md`

- [ ] **Step 1: 작성**

`references/pane-roles/review.md`:

````markdown
# [review] 역할 본문

당신의 임무는 dev 의 변경을 코드 리뷰하고 AC 별 만족 여부를 판정하는 것입니다.

## 입력

- `01-plan.md` (AC)
- `05-dev.md` (변경 파일 list + 결정 로그)
- 변경된 파일 자체 (직접 Read)

## 산출물 (`06-review.md`) schema

```markdown
# Review: {slug}

## 발견 이슈

(이슈 0건이면 "통과" 한 줄 명시)

| severity            | path:line     | issue | suggestion |
| ------------------- | ------------- | ----- | ---------- |
| blocker/major/minor | src/foo.ts:42 | ...   | ...        |

## AC 검증

- AC-1: ✓ — 코드 근거 (path:line)
- AC-2: ✗ — 이유
- AC-3: N/A — 본 작업 범위 아님
```

## 검증 가이드

- AC 별로 코드 근거를 path:line 으로 짚을 것 (orchestrator 가 가독)
- severity 정의:
  - **blocker**: 머지하면 안 됨 (보안/데이터 손실/기능 미구현)
  - **major**: 머지 가능하지만 다음 PR 에서 반드시 수정
  - **minor**: nitpick

## self-verify

`_guides/self-verify.md` 의 [review] 섹션.
````

- [ ] **Step 2: commit**

```bash
git add references/pane-roles/review.md
git commit -m "docs(pane-roles): review"
```

---

## Phase 7: References — orchestrator 정책

orchestrator (본 skill 이 발동된 메인 Claude Code 세션) 가 워크플로우를 진행하면서 참고하는 정책 문서들. 페인은 안 봄.

**Files:**

- Create: `references/workflow.md`
- Create: `references/model-routing.md`
- Create: `references/figma-integration.md`
- Create: `references/failure-recovery.md`

### Task 7.1: `references/workflow.md`

adaptive pipeline + 단계 흐름. spec Section 5 기반.

- [ ] **Step 1: 작성**

`references/workflow.md`:

````markdown
# Workflow

## Adaptive pipeline

plan pane 의 응답에서 task_classification 을 받아 다음 분기:

```
new-feature-no-ui    → plan → test-scenario → test-code + dev (병렬) → review
new-feature-with-ui  → plan → design(A) → test-scenario → test-code + dev → design(B) → review
bugfix               → plan(축약) → test-code(failing repro) → dev → review
refactor             → plan → dev → 기존 테스트 통과 검증 → review
design-only          → design (Figma 분석/제안) → review
```

분류가 모호하면 critical → 사용자 한 줄 보고 후 진행.

## 단계 공통 패턴

```
[stage]
  1. 이전 산출물 경로를 부트스트랩에 포함하여 pane spawn 또는 재사용
  2. cmux send + Enter 로 부트스트랩 메시지 전송
  3. pane: 작업 → 산출물 파일 작성 → self-verify → manifest.stages.<role>.self_verified 갱신
  4. pane: orchestrator 에게 "<role> done" 한 줄 응답
  5. orchestrator: send-and-poll.sh 의 poll_until_idle 로 응답 수신
  6. orchestrator: 2차 검증 (산출물 schema lint, 테스트 재실행, AC 매트릭스)
     → manifest.stages.<role>.orchestrator_verified 갱신
  7. ok 면 다음 단계, 실패면 1 retry, 그래도 실패면 critical
```

## Critical decision 발동 조건 (객관적 신호만)

- pane dead (capture 동일 60s + 모델 footer 없음) — 재spawn 도 실패
- 통합 테스트 3회 연속 실패
- 모델 한도 / billing 메시지 매칭
- task 분류 불가능 (plan pane 응답 모호)
- self-verify 또는 2차 검증 1 retry 후도 실패
- design 일치도 1 retry 후도 partial/fail
- resume 모드에서 이전 manifest 발견

주관적 판정 ("scope 변경", "destructive change") 은 critical 판정 기준에서 제외 — false positive 위험.
````

- [ ] **Step 2: commit**

```bash
git add references/workflow.md
git commit -m "docs(references): workflow"
```

### Task 7.2: `references/model-routing.md`

- [ ] **Step 1: 작성**

`references/model-routing.md`:

````markdown
# Model routing

## 기본 매핑

| 역할          | 기본 모델 | 근거                               |
| ------------- | --------- | ---------------------------------- |
| plan          | claude    | 아키텍처/추론 우위 (벤치마크 기반) |
| design        | claude    | Figma MCP 호환성                   |
| test-scenario | claude    | 명제 분해 정확도                   |
| test-code     | codex     | 구현 grinding 우위                 |
| dev           | codex     | 구현 grinding 우위                 |
| review        | claude    | 코드 리뷰 / 추론 우위              |

## Override 휴리스틱

기본 매핑은 휴리스틱이고 task 성격에 따라 orchestrator 가 조정 가능:

- **복잡한 동시성/디버깅 dev** → claude 로 교체 검토
- **단순 CRUD dev** → codex (기본값 유지, 빠름)
- **고품질 review 필요 (보안/돈 흐름)** → review 에 dual pane (claude + codex 동시) 검토
  - dual pane 발동은 critical → 사용자 한 줄 보고 ("review 에 듀얼 모델 띄움 — 토큰 2배")
- **codex 가 figma MCP 미지원** (2026-04 시점 미검증) → design 은 항상 claude 고정

override 결정은 critical 보고 대상 (사용자가 "왜 codex 대신 claude 썼지" 알아야 함).

## CLI 호출

```bash
# claude pane
claude --dangerously-skip-permissions

# codex pane
codex --dangerously-bypass-approvals-and-sandbox
```

`--dangerously-*` 플래그는 사용자가 cmux 환경 자체를 sandbox 로 보고 동의한 것 — 본 skill 의 모든 페인은 이 옵션으로 spawn (사용자 권한 prompt 차단).
````

- [ ] **Step 2: commit**

```bash
git add references/model-routing.md
git commit -m "docs(references): model-routing"
```

### Task 7.3: `references/figma-integration.md`

- [ ] **Step 1: 작성**

`references/figma-integration.md`:

````markdown
# Figma integration

design pane 만 Figma MCP 가 필요 (다른 페인은 불필요).

## A 단계 (plan 후)

design pane 부트스트랩 시 plan 의 figma_frame_urls 를 같이 주입. design pane 이 MCP 로 fetch.

## B 단계 (dev 후) — 일치도 검증

orchestrator 가 다음 흐름 수행:

```
1. 05-dev.md 에서 변경된 페이지/컴포넌트 경로 추출
2. manifest.visualization_command 로 dev 서버 또는 storybook 시작
   (사용자가 워크플로우 시작 시 명시. 비어있으면 critical)
3. Playwright 로 자동 스크린샷:
   .cmux-orchestrator/<slug>/screenshots/<component>-actual.png
4. design pane (B 단계) 에 메시지 전송:
   "B 단계 검증. 02-design.md 의 figma_frame_urls vs <screenshot 경로> 비교, 07-design-verify.md 작성"
5. design pane 이 정성 평가표 작성 (spacing / color / component variant / layout)
6. match_status ∈ {pass, partial, fail}
```

## 후속 처리

- pass → review 단계
- partial → fix_hint 묶어서 dev 재투입, 재검증 (1 retry)
- fail 또는 retry 후 partial 잔여 → critical

## Figma 없는 경우

plan 의 figma_frame_urls 가 비어있으면 design 단계 자체를 skip (workflow 분류가 `new-feature-no-ui` 등). orchestrator 는 이 상태를 정상으로 인식.

## visualization_command 자동 감지

manifest 의 `visualization_command` 가 null 이면 orchestrator 가 `package.json` scripts 를 보고 디폴트 추천:

- `storybook` 스크립트 있음 → `pnpm storybook` (포트 6006)
- `dev` 또는 `dev-app` 스크립트 → 그대로
- 없음 → critical, 사용자에게 명령 묻기

## Playwright 의존

orchestrator 가 cwd 에서 `npx playwright --version` 으로 설치 확인. 없으면 critical, 사용자에게 설치 요청 또는 visual verify skip 동의 묻기.
````

- [ ] **Step 2: commit**

```bash
git add references/figma-integration.md
git commit -m "docs(references): figma-integration"
```

### Task 7.4: `references/failure-recovery.md`

- [ ] **Step 1: 작성**

`references/failure-recovery.md`:

````markdown
# Failure recovery

## 카테고리별 정책

| 케이스                   | 감지                                       | 자동 대응                                     | critical                      |
| ------------------------ | ------------------------------------------ | --------------------------------------------- | ----------------------------- |
| Pane spawn 실패          | cmux exit code                             | 1 retry (1s 후)                               | 2회 실패                      |
| Pane dead                | capture 동일 60s + footer 없음             | pane 재spawn + 부트스트랩 재전송              | 재spawn 도 dead               |
| 모델 rate limit          | "rate limit" / "429" / "Try again in" 매칭 | 메시지 시간 파싱 → sleep → 재시도             | 60s 이상 대기 필요            |
| 모델 daily/billing 한도  | "exceeded" / "billing" / "credit" 매칭     | 즉시 critical                                 | (즉시)                        |
| 컨텍스트 ≥ 60%           | model footer token 추출                    | persistent: `/compact` 전송                   | 핵심 산출물 손실 위험 시 fork |
| 컨텍스트 ≥ 85%           | 동일                                       | 강제 fork (새 pane spawn + 부트스트랩 재주입) | 보고만 (작업 이어감)          |
| self-verify 1 retry 실패 | manifest 누적                              | 페인에 재요청                                 | retry 후 실패                 |
| 2차 검증 1 retry 실패    | manifest 누적                              | 차이 보여주고 재시도                          | retry 후 실패                 |
| 통합 테스트 3회 실패     | self-verify 결과 누적                      | dev pane 에 실패 로그 재투입                  | 3회째 실패                    |
| 사용자 강제 중단         | orchestrator 인터럽트                      | manifest 모든 stage status = paused           | 보고                          |

## 작업 재개 (resume)

orchestrator 호출 시 첫 단계:

1. feature_slug 인자 또는 task description hash 로 `.cmux-orchestrator/<slug>/manifest.json` 검사
2. 존재 + 일부 stage 가 done/paused → resume mode
   - 사용자 한 줄 보고: "이전 manifest 발견 (slug=X, plan/test-scenario done). 이어가시겠습니까?" — critical
   - done 인 stage skip
   - paused/failed stage 부터 재spawn
   - persistent pane 이 cmux tree 에 살아있으면 재사용, 죽었으면 새 spawn + 부트스트랩에 "이미 작성한 산출물 읽고 이어가라" 명시
3. 없으면 신규 워크플로우

명시적 호출: `--resume [slug]` 또는 자연어 "X 작업 재개". slug 없으면 `.cmux-orchestrator/` 스캔 후 사용자 선택.

## fork 절차

1. 새 pane spawn (같은 모델, 같은 lifecycle)
2. 부트스트랩 메시지에 추가:
   ```
   ## 이어받기
   - 이전 페인이 작성한 산출물: .cmux-orchestrator/{slug}/{artifact}.md (반드시 읽고 시작)
   - manifest.stages.{role}.status 가 running 으로 남아있을 수 있음 → 본인이 갱신
   ```
3. 이전 페인은 닫음 (`cmux close-surface`)
4. manifest.panes 의 이전 surface ref `alive=false` 마킹, 새 ref 추가
````

- [ ] **Step 2: commit**

```bash
git add references/failure-recovery.md
git commit -m "docs(references): failure-recovery"
```

---

## Phase 8: SKILL.md 본문 + 슬래시 명령

### Task 8.1: SKILL.md 본문

orchestrator 의 메인 결정 트리. 진보적 공개 — 상세는 references/ 로 위임.

**Files:**

- Modify: `SKILL.md` (frontmatter 유지, 본문 추가)

- [ ] **Step 1: 본문 작성**

`SKILL.md` 의 frontmatter 아래에 append:

````markdown
# cmux-orchestrator

cmux 워크스페이스 위에서 Claude Code 와 Codex 세션을 역할별 페인으로 자동 오케스트레이션하는 skill.

## 발동 조건 (description 외)

본 skill 은 **multi-step 구현 작업**에서만 발동. 단순 한 줄/한 파일 편집, 단발 자문은 다른 skill (`cmux-pane-chat`, `dispatching-parallel-agents`) 영역.

## 워크플로우

### 0. 사전 점검 + resume 감지

```bash
# cmux 환경 sanity
[ -n "$CMUX_SOCKET_PATH" ] || { echo "cmux 환경 아님"; exit 1; }
which cmux >/dev/null

# resume 감지
slug=$(extract_slug_from_task_description "$TASK_DESC")  # 또는 사용자 인자 --resume <slug>
if [ -f "<repo>/.cmux-orchestrator/$slug/manifest.json" ]; then
  # 이전 manifest 발견 → critical 보고 후 resume mode
fi
```

### 1. Workspace 부트스트랩 (resume 아닐 때)

1. `cmux new-workspace --cwd <repo>` (단, `--here` 옵션 시 skip)
2. workspace 안에 `.cmux-orchestrator/<slug>/` + `_guides/` 디렉토리
3. `references/{cross-pane-chat,handoff-conventions,self-verify}.md` 를 `_guides/` 로 단순 복사
4. `scripts/manifest.sh` 의 `manifest_init` 호출

### 2. Plan pane spawn → AC 도출

1. plan pane spawn (claude, persistent)
2. 부트스트랩 메시지 전송 (공통 헤더 + `references/pane-roles/plan.md` 본문)
3. send-and-poll → 응답 수신 → 01-plan.md 파일 존재 + manifest 갱신 확인
4. 2차 검증: AC 형식 lint
5. plan 의 task_classification 으로 다음 단계 분기 (`references/workflow.md`)

### 3. 분류별 단계 진행

`references/workflow.md` 의 adaptive pipeline 따름.

각 단계는 공통 패턴 (single-stage flow):

1. 페인 spawn (또는 persistent 재사용)
2. 부트스트랩 메시지 전송
3. send-and-poll
4. self-verify 결과 확인 (manifest)
5. orchestrator 2차 검증
6. ok → 다음 / fail → 1 retry → 그래도 fail → critical

### 4. (UI 작업 시) Design B 단계

`references/figma-integration.md` 의 B 단계 절차.

### 5. Review

review pane 에 변경 파일 list + AC 전송 → 06-review.md → blocker 있으면 dev 재투입 (1 retry).

### 6. 종료

- task-scoped pane 닫기 (test-scenario / test-code / dev)
- persistent pane 유지 (다음 작업에 재사용)
- orchestrator 가 사용자에게 결과 요약 + `.cmux-orchestrator/<slug>/` 경로 보고
- 사용자가 "끝" 명령 시 cmux close-workspace

## Critical decision 보고 형식

객관적 신호로 critical 판정 시 사용자에게 한 줄 보고. 예:

> ⚠ critical: 통합 테스트 3회 실패 (vitest 출력: src/foo.test.ts에서 timeout). dev pane 에 실패 로그 재투입했지만 같은 결과. .cmux-orchestrator/feature-x/manifest.json 의 stages.dev.failures 참고.

응답 안 기다리고 진행 (사용자 메모리: "허락 없이 바로 진행"). 사용자가 명시적으로 멈추면 paused.

## 참조 트리

- 워크플로우 분기 → `references/workflow.md`
- 모델 매핑 → `references/model-routing.md`
- Figma 절차 → `references/figma-integration.md`
- 실패/재개 → `references/failure-recovery.md`
- 페인 부트스트랩 메시지 schema → 본 SKILL.md 의 "부트스트랩 메시지 템플릿" 섹션 (아래)
- 역할별 본문 → `references/pane-roles/<role>.md`
- 페인용 가이드 (워크스페이스 \_guides/ 로 복사) → `references/{handoff-conventions,cross-pane-chat,self-verify}.md`

## 부트스트랩 메시지 템플릿

각 페인 spawn 직후 orchestrator 가 전송하는 단일 메시지. 변수 치환 후 `send_text_with_enter` 로.

```text
당신은 cmux-orchestrator 워크플로우의 [{role}] 페인입니다.

## Workspace
- repo: {cwd}
- feature_slug: {slug}
- 매니페스트: .cmux-orchestrator/{slug}/manifest.json
- 가이드: .cmux-orchestrator/{slug}/_guides/

## 당신의 산출물
- 쓰기 대상: .cmux-orchestrator/{slug}/{artifact_filename}
- schema: 아래 "역할 본문" 참조

## 다른 페인 (cross-pane 자문)
| 역할 | surface | 모델 |
|------|---------|------|
| plan         | surface:{N1} | claude |
| design       | surface:{N2} | claude |
| test-scenario| surface:{N3} | claude |
| test-code    | surface:{N4} | codex  |
| dev          | surface:{N5} | codex  |
| review       | surface:{N6} | claude |
| orchestrator | surface:{N0} | claude |

자문 필요 시 _guides/cross-pane-chat.md 규약 따름. 짧은 자문만, 작업 위임 금지,
상대 작업 중에는 메시지 보내지 말 것.

## Acceptance Criteria
{ac_list}    # plan 단계 이전이면 "(plan에서 정의 예정)"

## 완료 시 self-verify
1. _guides/self-verify.md 의 [{role}] 체크리스트 실행
2. manifest.stages.{role}.self_verified 에 결과 + evidence 기록
3. orchestrator 에게 "{role} done" 한 줄 응답

## 안전
- destructive 명령 금지
- 워크스페이스 .cmux-orchestrator/ 외부 쓰기 금지 (단, dev pane은 repo 본 코드 가능)
- 모르겠으면 orchestrator 에게 한 줄 보고 후 대기

---

{role_body}
```

치환 변수:

- `{role}`, `{cwd}`, `{slug}`, `{artifact_filename}`, `{ac_list}`, `{N0..N6}`, `{role_body}`
- `{role_body}` = `references/pane-roles/{role}.md` 의 본문 (frontmatter 제외)

## scripts 사용 안내

- `scripts/manifest.sh`: manifest 갱신 헬퍼. 항상 `MANIFEST_PATH` env 설정 후 source.
- `scripts/pane-status.sh`: capture 분석 (idle/dead/failure 신호 / context %).
- `scripts/send-and-poll.sh`: cmux send + Enter + polling (cmux send-key Enter 함정 회피).
- `scripts/compact-or-fork.sh`: context % 임계 시 /compact 또는 fork 결정.

각 스크립트의 함수는 source 후 직접 호출.
````

- [ ] **Step 2: 본문 길이 확인 — 500줄 이하 권장**

```bash
wc -l SKILL.md
```

Expected: ~250줄 정도. 500 미만이면 OK.

- [ ] **Step 3: commit**

```bash
git add SKILL.md
git commit -m "feat(skill): add SKILL.md body"
```

### Task 8.2: 슬래시 명령 — `commands/cmux-orchestrate.md`

- [ ] **Step 1: 작성**

`commands/cmux-orchestrate.md`:

```markdown
---
description: cmux 위에서 plan/design/test/dev/review 페인을 자동 오케스트레이션해 작업 수행
---

cmux-orchestrator skill 을 발동하여 사용자 요청을 multi-pane 워크플로우로 처리한다.

## 인자

- 인자 없음: 마지막 사용자 메시지를 task description 으로 사용
- `--resume [slug]`: 재개 모드. slug 없으면 `.cmux-orchestrator/` 스캔 후 선택 (critical)
- `--here`: 새 workspace 만들지 않고 현재 cmux workspace 에 페인 추가 (기본: 새 workspace)
- `--visualization-command "<cmd>"`: UI 일치도 검증용 명령 명시 (생략 시 자동 감지)

## 호출

1. `~/.claude/skills/cmux-orchestrator/SKILL.md` 의 워크플로우 따름
2. 첫 단계: 사전 점검 → workspace 부트스트랩 → plan
3. critical decision 만 사용자 보고, 그 외 자동 진행
```

- [ ] **Step 2: commit**

```bash
git add commands/cmux-orchestrate.md
git commit -m "feat(skill): add slash command"
```

---

## Phase 9: Evals + README

### Task 9.1: `evals/evals.json`

- [ ] **Step 1: 트리거 + 동작 평가 작성**

`evals/evals.json`:

```json
{
  "skill_name": "cmux-orchestrator",
  "trigger_evals": [
    {
      "query": "feature/startup-api-bulk 에서 신청서 폼이랑 검증 로직 한 번에 만들어줘. plan, test, 구현, 리뷰 다 거쳐서.",
      "should_trigger": true
    },
    {
      "query": "claude 랑 codex 같이 띄워서 이 PR 작업해",
      "should_trigger": true
    },
    {
      "query": "여러 역할로 나눠서 결제 모듈 한 번에 만들어줘",
      "should_trigger": true
    },
    {
      "query": "오케스트레이션 한 번 해줘 — 회원 가입 플로우 전체",
      "should_trigger": true
    },
    {
      "query": "이 한 줄만 고쳐줘 — userName -> user_name",
      "should_trigger": false
    },
    { "query": "이 함수 어떻게 동작해?", "should_trigger": false },
    {
      "query": "옆 페인 codex 한테 이거 한 번 봐달라고 해줘",
      "should_trigger": false
    },
    {
      "query": "dispatch parallel agents 로 테스트 3개 동시에 고쳐줘",
      "should_trigger": false
    }
  ],
  "behavior_evals": [
    {
      "id": 1,
      "name": "bugfix-no-ui",
      "prompt": "src/util/parsePhone.ts 의 한국 번호 파싱 버그 수정. 010-1234-5678 같은 표준 포맷이 fail. AC 정의 → RED 테스트 → fix → review 거쳐서.",
      "expected_output": "manifest.json 에 plan/test-code/dev/review 4단계 done, 06-review.md 통과, AC ≥ 1 ✓"
    },
    {
      "id": 2,
      "name": "new-feature-with-figma",
      "prompt": "Figma frame X 기반 신청서 폼 구현. design-system 컴포넌트 사용. plan-design-test-dev-review 풀 파이프라인.",
      "expected_output": "07-design-verify.md match_status=pass 또는 partial(이슈 ≤ 2), 모든 AC ✓"
    },
    {
      "id": 3,
      "name": "resume",
      "prompt": "(eval-1 의 manifest 가 plan done, test-code paused 상태에서) 재개해줘",
      "expected_output": "plan skip, test-code 부터 이어감, 최종 manifest done"
    }
  ]
}
```

- [ ] **Step 2: commit**

```bash
git add evals/evals.json
git commit -m "test(skill): add evals"
```

### Task 9.2: `README.md` 본문

- [ ] **Step 1: 작성**

`README.md`:

````markdown
# cmux-orchestrator

cmux 워크스페이스 위에서 Claude Code 와 Codex 세션을 역할별 페인으로 자동 오케스트레이션해 한 작업을 끝까지 처리하는 skill.

## 환경 요구

- macOS + cmux.app 설치
- claude CLI 로그인 완료
- codex CLI 로그인 완료
- jq, bash 4+, bats (테스트)
- 선택: Playwright (UI 일치도 검증), Figma MCP (design pane)

## 사용

```bash
# 슬래시 명령 (Claude Code 안에서)
/cmux-orchestrator:cmux-orchestrate "기능 X 만들어줘"

# 또는 자연어 트리거
"여러 역할로 나눠서 X 만들어줘"
```

## 옵션

- `--resume [slug]`: 작업 재개
- `--here`: 현재 workspace 에 페인 추가 (기본: 새 workspace)
- `--visualization-command "<cmd>"`: UI 검증용 dev 서버/storybook 명령

## 디렉토리 구조

```
~/.claude/skills/cmux-orchestrator/
├── SKILL.md
├── commands/cmux-orchestrate.md
├── scripts/
│   ├── manifest.sh
│   ├── pane-status.sh
│   ├── send-and-poll.sh
│   └── compact-or-fork.sh
├── references/
│   ├── workflow.md
│   ├── model-routing.md
│   ├── figma-integration.md
│   ├── failure-recovery.md
│   ├── handoff-conventions.md
│   ├── cross-pane-chat.md
│   ├── self-verify.md
│   └── pane-roles/
│       ├── plan.md
│       ├── design.md
│       ├── test-scenario.md
│       ├── test-code.md
│       ├── dev.md
│       └── review.md
├── evals/evals.json
└── tests/
    ├── scripts/      (bats 테스트)
    └── fixtures/     (capture mock)
```

## 테스트 실행

```bash
cd ~/.claude/skills/cmux-orchestrator
bats tests/scripts/
```

## 트러블슈팅

| 증상             | 원인 / 대응                                                                         |
| ---------------- | ----------------------------------------------------------------------------------- |
| "cmux 환경 아님" | cmux.app 안에서 실행해야 함. `$CMUX_SOCKET_PATH` 비어있으면 그냥 일반 터미널.       |
| pane spawn 실패  | cmux 권한 prompt 가 떠있을 수 있음. cmux 화면 확인.                                 |
| 모델 한도 메시지 | rate limit 자동 sleep 후 재시도. billing 한도면 즉시 critical (사용자 처리).        |
| context 폭증     | 60% 에서 /compact, 85% 에서 fork. 사용자가 한 작업이 너무 크면 spec 을 잘게 나누기. |

## 디자인 spec

`docs/superpowers/specs/2026-04-29-cmux-orchestrator-design.md` (별도 위치)

## 라이선스 / 책임

본 skill 은 `--dangerously-skip-permissions` 와 `--dangerously-bypass-approvals-and-sandbox` 를 사용한다. cmux 워크스페이스 자체를 sandbox 로 보고 사용자가 동의한 환경에서만 사용. destructive 명령은 모든 페인에서 금지로 강제하지만 100% 보장 아님 — 사용자가 워크플로우를 모니터링.
````

- [ ] **Step 2: commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Phase 10: Dry-run + 검증

### Task 10.1: 전체 테스트 통과 확인

- [ ] **Step 1: bats 전체 실행**

```bash
cd ~/.claude/skills/cmux-orchestrator
bats tests/scripts/
```

Expected: 모든 테스트 PASS.

- [ ] **Step 2: 실패하면 패치 후 재실행 → PASS 까지**

### Task 10.2: 간단 bugfix dry-run (수동)

cmux 환경에서 사용자가 직접 호출. 본 plan 안에서는 절차만 명시.

- [ ] **Step 1: dry-run 시나리오**

QPLACE 레포에서 작은 버그 (예: `apps/api-qplace-v2/src/util/<유틸>` 의 단순 함수) 를 골라:

```
/cmux-orchestrator:cmux-orchestrate "apps/api-qplace-v2/src/util/<file>.ts 의 <함수> 가 빈 문자열 입력 시 throw 안 함. 빈 문자열 → ''로 반환되게 fix. AC 정의 → RED 테스트 → fix → review."
```

- [ ] **Step 2: 워크플로우 진행 모니터링**

체크포인트:

- plan pane 이 스폰되고 01-plan.md 작성
- AC 가 명제 형식으로 1개 이상
- task_classification = bugfix
- test-code pane 이 RED 확인
- dev 가 통과
- review 가 통과 또는 minor 만

- [ ] **Step 3: 발견된 이슈 패치**

일어난 이슈를 issues.md 에 기록 후 hotfix.

- [ ] **Step 4: commit**

```bash
git add -A
git commit -m "fix: dry-run findings patch"
```

### Task 10.3: 트리거 description optimization (선택)

- [ ] **Step 1: skill-creator 의 description optimization 호출**

skill-creator 의 `scripts/run_loop.py` 를 사용:

```bash
python -m scripts.run_loop \
  --eval-set ~/.claude/skills/cmux-orchestrator/evals/evals.json \
  --skill-path ~/.claude/skills/cmux-orchestrator \
  --model claude-opus-4-7 \
  --max-iterations 5 \
  --verbose
```

- [ ] **Step 2: best_description 으로 SKILL.md frontmatter 업데이트**

- [ ] **Step 3: commit**

```bash
git add SKILL.md
git commit -m "feat(skill): optimize description for trigger accuracy"
```

---

## Phase 11 (선택): 운영 후 재평가

실 사용 1주일 후:

### Task 11.1: 사용 로그 수집

- [ ] 실 호출 사례에서 critical 보고 빈도, false positive 패턴 수집.
- [ ] manifest 의 `failures` 필드를 발생 케이스별 누적해서 본 plan 의 임계값 (60s pane dead, 60% context, 3회 통합 테스트 실패) 재조정.

### Task 11.2: 미해결 항목 재검토

spec Section 12 의 Open Questions 중 운영에서 답이 나온 것 → spec/plan 갱신:

- visualization command 자동 감지 정확도
- codex 의 figma MCP 지원 여부
- cross-workspace pane 통신 필요성
- CI 통합 시나리오
- telemetry 필요성

---

## Self-review

본 plan 의 spec coverage 와 placeholder 점검 결과:

**Spec coverage 매트릭스:**

| spec section         | 커버 task                                  |
| -------------------- | ------------------------------------------ |
| 1. 목적/시나리오     | Task 9.2 (README) + Task 0.1 (description) |
| 2. 핵심 결정         | 7.1 / 7.2 / 7.3 / 7.4                      |
| 3. 아키텍처          | 8.1 (SKILL.md)                             |
| 4. 디렉토리 구조     | 0.1 + 모든 task                            |
| 5. 워크플로우        | 7.1 + 8.1                                  |
| 6. AC + 검증         | 5.3 + 6.1~6.6 + 7.1                        |
| 7. 부트스트랩 메시지 | 8.1 (템플릿) + 6.1~6.6 (역할 본문)         |
| 8. manifest schema   | 1.1~1.5 + 5.1                              |
| 9. 실패·복구         | 2.1~2.6 + 4.1~4.2 + 7.4                    |
| 10. 슬래시 + 트리거  | 8.2 + 0.1 (frontmatter description)        |
| 11. evals            | 9.1                                        |

전 섹션 커버됨.

**Placeholder scan:** "TBD" / "TODO" / "later" 검색 → 없음.

**Type/네이밍 일관성:** `manifest_*` 함수명, `pane-roles/<role>.md` 경로, `MANIFEST_PATH` env, `surface:N` 표기 모두 task 간 일관.

---

## 실행 옵션

Plan 완성. 두 옵션 중 선택:

**1. Subagent-Driven (권장)** — task 마다 fresh subagent 디스패치, task 사이에 사용자 리뷰, 빠른 반복.

- REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`

**2. Inline Execution** — 본 세션에서 task 들 batch 실행, 체크포인트마다 사용자 리뷰.

- REQUIRED SUB-SKILL: `superpowers:executing-plans`

어느 쪽?
