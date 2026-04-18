---
name: release-promote
description: 앱스토어/플레이스토어 프로덕션 승격. TestFlight→App Store, 내부트랙→프로덕션 릴리즈.
user_invocable: true
allowed_tools:
  - Bash
  - Read
---

# /release-promote — 프로덕션 승격

## 실행

### 1. 상태 확인

먼저 `/release-status`로 승격 가능 상태인지 확인한다:
- iOS: `PENDING_DEVELOPER_RELEASE`여야 함
- Android: internal 트랙에 릴리즈가 있어야 함

### 2. 승격 실행

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release store-promote
```

## 안전장치

- 승격 불가 상태면 이유 출력 후 중단
- 사용자 확인을 반드시 받은 후 실행
