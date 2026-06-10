---
name: release-status
description: 앱스토어/플레이스토어 심사 상태 확인. iOS App Store 심사 상태, Android Play Store 트랙 상태 조회.
user_invocable: true
allowed_tools:
  - Bash
  - Read
---

# /release-status — 스토어 심사 상태 확인

## 실행

Codex plugin에서 wrapper 경로는 plugin root의 `bin/app-release`이다. 경로가 불분명하면 `WRAPPER=$(find ~/.codex ~/.agents ~/plugins -path "*/app-release/bin/app-release" -type f | head -1)` 로 해석한 뒤 아래 `$WRAPPER` 자리에 사용한다.


1. 현재 프로젝트에서 릴리즈 설정을 찾는다:

```bash
$WRAPPER store-status
```

2. JSON 결과를 파싱하여 표로 표시한다:

### iOS
| 항목 | 값 |
|------|------|
| 버전 | {version} |
| 상태 | {state} |
| 심사 상태 | {reviewState} |

### Android
| 트랙 | 버전 코드 | 상태 | 출시 비율 |
|------|-----------|------|----------|
| internal | {internal.versionCode} | {internal.status} | — |
| production | {production.versionCode} | {production.status} | {production.userFraction} |

## 오류 처리

- `release.config.json not found`: 프로젝트 루트에 `release.config.json`을 만들라고 안내
- `node_modules missing`: `cd ~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release && npm install`

## 교훈 / 함정

- **상태 ≠ 거절 사유.** 이 명령이 보여주는 iOS `reviewState`(REJECTED 등)는 **상태일 뿐**이고, **거절 사유 원문은 API에 없다.** 사유는 ASC Resolution Center(웹, 로그인 필요)에만 있다. REJECTED가 보이면 `/release-fix`로 넘어가되, 사유 확인은 Resolution Center에서 해야 한다. 상세: `../../LESSONS.md` L1.
