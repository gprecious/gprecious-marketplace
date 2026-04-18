---
name: release-fix
description: 스토어 심사 거절 대응. 거절 사유 분석, 메타데이터 자동 수정, 재제출.
user_invocable: true
allowed_tools:
  - Bash
  - Read
  - Write
  - Edit
---

# /release-fix — 심사 거절 대응

## 실행

### 1. 거절 사유 분석

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release rejection-analyzer
```

### 2. 분석 결과 표시

거절된 플랫폼과 사유를 표로 표시. 권장 수정안을 제안한다.

### 3. 사용자 승인 후 수정

`release.config.json.store`를 편집하거나, 메타데이터를 직접 수정 후 `/release-metadata --apply`로 재반영.
