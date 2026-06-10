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

Codex plugin에서 wrapper 경로는 plugin root의 `bin/app-release`이다. 경로가 불분명하면 `WRAPPER=$(find ~/.codex ~/.agents ~/plugins -path "*/app-release/bin/app-release" -type f | head -1)` 로 해석한 뒤 아래 `$WRAPPER` 자리에 사용한다.


### 1. 거절 사유 분석

```bash
$WRAPPER rejection-analyzer
```

> ⚠️ **`rejection-analyzer`는 거절 사유 원문을 읽지 못한다.** ASC API는 review **상태**(REJECTED)만 노출하고 사유 텍스트는 노출하지 않는다. analyzer는 상태 문자열만 보고 분류하므로 iOS 거절은 사실상 항상 `category: unknown`이 된다. **거절 사유 원문은 Apple 이메일(링크만 있음)도 아니고 API도 아니라 Resolution Center(웹)에만 있다** → `https://appstoreconnect.apple.com/apps/<ascAppId>/distribution/reviewsubmissions/details/<submissionId>`. 로그인은 사용자가 해야 한다(Claude는 비밀번호·2FA 불가). 사람이 사유 텍스트를 읽어와야 분류·수정이 가능하다. 상세: `../../LESSONS.md` L1·L2.

### 2. 분석 결과 표시

거절된 플랫폼과 사유를 표로 표시. 권장 수정안을 제안한다. `unknown`이면 사용자에게 Resolution Center에서 사유 원문을 확인해 전달해달라고 요청한 뒤, 그 텍스트로 카테고리(metadata/binary/policy)를 판단한다.

### 3. 사용자 승인 후 수정

`release.config.json.store`를 편집하거나, 메타데이터를 직접 수정 후 `/release-metadata --apply`로 재반영.
