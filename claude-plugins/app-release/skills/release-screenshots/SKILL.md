---
name: release-screenshots
description: 스토어 스크린샷 생성 및 업로드. 템플릿 기반 합성 후 Fastlane으로 업로드.
user_invocable: true
allowed_tools:
  - Bash
  - Read
---

# /release-screenshots — 스크린샷 생성 + 업로드

## 실행

### 1. 생성

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release screenshots --generate
```

사이즈별/로케일별 결과를 요약.

### 2. 업로드 (사용자 확인 후)

```bash
~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release/bin/app-release screenshots --upload
```

Fastlane `deliver` / `supply`를 사용하므로 프로젝트에 `fastlane/` 설정이 필요하다.
