---
name: release
description: 모바일 앱 풀 릴리즈 파이프라인. 사전점검 → 메타데이터 → 스크린샷 → 빌드+제출 → 후속안내. Expo/Capacitor 지원.
user_invocable: true
argument_hint: "[--skip-screenshots] [--skip-metadata] [--cloud] [--platform=ios|android|all]"
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
- `--cloud` — EAS 클라우드 빌드 사용 (Expo 전용). 기본은 로컬 빌드
- `--platform=ios|android|all` — 빌드 대상 (기본: all)

프로젝트 스택은 `release.config.json.stack`에서 자동 결정됨 (expo/capacitor/flutter).

## 실행

WRAPPER 경로: `~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release`

### 1. 사전 점검

```bash
git status --short
```
커밋되지 않은 변경사항이 있으면 계속 진행할지 사용자에게 확인.

스크립트는 cwd에서 상위로 `release.config.json`을 탐색한다. 없으면 에러.

### 2. 메타데이터 (`--skip-metadata`가 없을 때)

```bash
<WRAPPER> store-metadata           # dry-run
# 변경 사항이 있으면 사용자 확인 후
<WRAPPER> store-metadata --apply
```

### 3. 릴리즈 노트 생성

`git log $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --oneline --no-merges`로 커밋을 수집해 한/영 릴리즈 노트 초안 작성.

- AI 언급 절대 금지
- 사용자 대면 변경사항만 포함 (내부 리팩토링/테스트 제외)

### 4. 스크린샷 (`--skip-screenshots`가 없을 때)

```bash
<WRAPPER> screenshots --generate
# 미리보기 후 사용자 확인
<WRAPPER> screenshots --upload
```

### 5. 빌드 + 제출

**기본: 로컬 빌드** (Expo의 경우 `eas build --local`). 클라우드 빌드 필요 시 `--cloud` 지정.

```bash
<WRAPPER> release-orchestrator --platform=<platform>
# 클라우드 빌드
<WRAPPER> release-orchestrator --platform=<platform> --cloud
```

로컬 빌드 환경 점검 (Expo):
```bash
command -v java >/dev/null && java -version 2>&1 | head -1
echo "JAVA_HOME=$JAVA_HOME"; echo "ANDROID_HOME=$ANDROID_HOME"
xcodebuild -version 2>&1 | head -1
```
누락 시 `--cloud` fallback을 제안한다.

### 6. 후속 안내

- 심사 상태: `/release-status`
- 승격: `/release-promote`
- 거절 대응: `/release-fix`

## 안전장치

- 빌드 전 반드시 사용자 확인
- 메타데이터 변경은 dry-run 먼저
- 릴리즈 노트에 AI 언급 금지
- 로컬 빌드 환경 누락 시 강제 진행 금지 (fallback 제안)
