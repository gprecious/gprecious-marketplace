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
