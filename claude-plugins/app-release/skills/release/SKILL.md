---
name: release
description: 모바일 앱 풀 릴리즈 파이프라인. 사전점검 → 메타데이터 → 스크린샷 → 빌드+제출 → 후속안내.
user_invocable: true
argument_hint: "[--skip-screenshots] [--skip-metadata]"
allowed_tools:
  - Bash
  - Read
  - Write
  - Edit
---

# /release — 모바일 앱 풀 릴리즈 파이프라인

## 인자

- `--skip-screenshots` — 스크린샷 생성/업로드 건너뛰기
- `--skip-metadata` — 메타데이터 동기화 건너뛰기

## 실행

### 1. 사전 점검

- `git status --short` — 커밋되지 않은 변경사항 경고
- 프로젝트 루트의 `release.config.json` 확인 (스킬이 호출한 스크립트가 자동 탐색)

### 2. 메타데이터 (선택)

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release store-metadata
```
변경사항이 있으면 사용자 확인 후 `--apply`.

### 3. 스크린샷 (선택)

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release screenshots --generate
# 확인 후
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release screenshots --upload
```

### 4. 릴리즈 노트 생성

`git log $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --oneline --no-merges`로 커밋을 수집하여 한/영 릴리즈 노트 초안을 제안한다.
- AI 언급 절대 금지
- 사용자 대면 변경사항만 포함

### 5. 빌드 + 제출

사용자 확인 후:
```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release release-orchestrator all
```
스택(Expo/Capacitor/Flutter)은 `release.config.json.stack`에서 자동 결정.

### 6. 후속 안내

> "빌드가 시작되었습니다. 심사 상태: `/release-status`, 승격: `/release-promote`, 거절 대응: `/release-fix`"

## 안전장치

- 빌드 실행 전 반드시 사용자 확인
- 릴리즈 노트에 AI 언급 금지
- 에러 발생 시 중단 + 수동 대안 안내
