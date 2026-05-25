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

## 교훈 / 함정 (제출 전 필수 체크)

- **Guideline 2.3.7 Accurate Metadata — 스크린샷에 가격/"무료" 문구 금지.** 첫 제출에서 흔한 거절. 캡션 텍스트뿐 아니라 **목업 안의 UI 텍스트(CTA 버튼 등)**도 대상이다. "무료(free)", "할인", "sale", 통화기호(₩/$/원)는 모두 가격 참조로 간주된다.
  - **생성 전 소스 스캔:** `rg -n "무료|free|할인|sale|₩|원|\$[0-9]" <screenshot-source>` — 검출되면 문구를 바꾼 뒤 생성. 가격 홍보는 스크린샷이 아니라 앱 설명(description)에.
  - 생성 후 출력 PNG를 직접 열어 확인(텍스트가 이미지에 래스터화되어 grep 불가).
- **업로드 슬롯 매핑 확인:** 생성기의 인덱스 순서가 ASC 표시 순서·장수와 다를 수 있다(예: 템플릿 8장 vs ASC 7장). 교체 업로드 시 어느 파일이 어느 슬롯인지 확인.
- **Playwright 기반 생성기(프로젝트별)는 레포 의존성이 아닐 수 있다.** 워크스페이스 모노레포에서 `npm install --prefix <subdir>`가 미공개 워크스페이스 패키지 404로 실패하면, 격리된 임시 디렉터리에 playwright만 설치해 절대경로로 렌더한다(브라우저 바이너리는 `~/Library/Caches/ms-playwright`에 캐시됨).
- 상세: `../../LESSONS.md` L3·L4.
