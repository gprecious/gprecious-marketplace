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

Codex plugin에서 wrapper 경로는 plugin root의 `bin/app-release`이다. 경로가 불분명하면 `WRAPPER=$(find ~/.codex ~/.agents ~/plugins -path "*/app-release/bin/app-release" -type f | head -1)` 로 해석한 뒤 아래 `$WRAPPER` 자리에 사용한다.


### 1. 생성

```bash
$WRAPPER screenshots --generate
```

사이즈별/로케일별 결과를 요약.

### 2. 업로드 (사용자 확인 후)

```bash
$WRAPPER screenshots --upload
```

Fastlane `deliver` / `supply`를 사용하므로 프로젝트에 `fastlane/` 설정이 필요하다.
