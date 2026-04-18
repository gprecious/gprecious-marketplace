---
name: release-metadata
description: 스토어 메타데이터 동기화. release.config.json의 store 섹션을 단일 소스로 App Store Connect + Google Play 업데이트.
user_invocable: true
allowed_tools:
  - Bash
  - Read
---

# /release-metadata — 메타데이터 동기화

## 실행

### 1. Dry-run

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release store-metadata
```

### 2. 결과 표시

| 플랫폼 | 로케일 | 필드 | 현재 값 | 변경 값 |

`totalChanges === 0`이면 "모든 메타데이터가 최신 상태"라고 안내.

### 3. 적용 (사용자 확인 후)

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release store-metadata --apply
```

## 안전장치

- 항상 dry-run 먼저
- iOS 업데이트는 현재 편집 가능한 버전에만 적용됨 (신규/거절/준비 상태)
