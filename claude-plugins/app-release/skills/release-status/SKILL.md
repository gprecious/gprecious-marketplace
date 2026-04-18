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

1. 현재 프로젝트에서 릴리즈 설정을 찾는다:

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release store-status
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
