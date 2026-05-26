# 릴리즈 교훈 (반복 실수 방지)

> 실제 릴리즈에서 얻은 함정·교훈을 누적하는 파일. 새 교훈은 **맨 위 날짜 블록**으로 추가한다.
> 각 SKILL.md는 자기와 관련된 항목을 인라인 요약 + 이 파일을 포인터로 참조한다.
> 표기: `[일반]` = 모든 앱 공통, `[프로젝트:<이름>]` = 특정 프로젝트 한정.

---

## 2026-05-25 — NeonNovel iOS 첫 제출 거절(2.3.7) 대응

### L1. `[일반]` 거절 **사유 원문**은 API에도 이메일에도 없다 — Resolution Center(웹)에만 있다
- ASC 공개 API(`/v1/apps/{id}/appStoreVersions`)는 review **STATE**(`appStoreState`=`REJECTED` 등)만 노출한다. **거절 사유 텍스트는 노출하지 않는다.**
- Apple 거절 **이메일에는 링크만** 있고 사유 본문이 없다.
- 실제 사유는 ASC 로그인 후 여기에 있다:
  `https://appstoreconnect.apple.com/apps/<ascAppId>/distribution/reviewsubmissions/details/<submissionId>`
  → 페이지 하단 "메시지" 영역에 Guideline 번호 + Issue Description + Next Steps.
- **이 플러그인 영향(중요):** `scripts/rejection-analyzer.ts`의 `analyzeIos()`는 `details = "iOS version X state: REJECTED"` 문자열만 만들어 `categorizeRejection(details)`에 넘긴다. 이 문자열엔 metadata/binary/policy 키워드가 없으므로 **항상 `category: unknown, autoFixable: false`** 가 된다. 즉 **analyzer는 구조상 사유를 절대 분류하지 못한다** — 사유 텍스트를 입력으로 받지 않기 때문.
- **올바른 워크플로:** REJECTED 감지 → 사람이 Resolution Center를 열어 사유를 읽음 → 그 텍스트를 `/release-fix`에 전달해 분류·수정. analyzer의 `unknown` 제안("App Store Connect에서 직접 확인하세요")이 실질적으로 맞는 안내다.
- **개선 과제(미구현):** analyzer가 최신 reviewSubmission의 `submissionId`를 함께 출력해 Resolution Center 딥링크를 만들어주면 사람 확인이 빨라진다. (사유 텍스트 자체는 API로 못 가져옴.)

### L2. `[일반]` ASC 로그인은 Claude가 넘을 수 없는 경계다
- Claude가 할 수 있는 것: ASC 페이지 이동, **Apple ID 이메일** 입력, 비밀번호 단계까지 진행, 로그인 후 Resolution Center 읽기/스크린샷.
- Claude가 **못 하는 것: 원시 비밀번호 직접 입력**(채팅·1Password CLI·파일 등 출처 불문, 보안 규칙). 허용되는 유일한 우회는 **1Password 브라우저 확장 자동완성**(값이 Claude를 거치지 않음)이나, 확장 미설치/잠금이면 작동하지 않는다(`Cmd+\` 무반응). **2FA**는 사용자 신뢰 기기 필요.
- 결론: **로그인은 사람 단계.** Claude는 이메일까지 깔아두고 비밀번호+2FA를 사용자에게 넘긴 뒤, 로그인된 세션에서 이어받는다.

### L3. `[일반]` Guideline 2.3.7 Accurate Metadata — 스크린샷에 가격/"무료" 문구 금지 (첫 제출 흔한 거절)
- 스크린샷의 **캡션 텍스트**와 **목업 안의 UI 텍스트(CTA 버튼 등) 둘 다** 가격 참조 금지.
- "무료(free)", "할인(discount)", "sale", 통화기호(₩/$/원)는 **모두 가격 참조로 간주**된다(무료·할인 포함).
- **제출 전 필수 체크:** 스크린샷 소스에서 가격성 단어 스캔.
  예: `rg -n "무료|free|할인|sale|₩|원|\$[0-9]" <screenshot-source>`
- 가격을 홍보하려면 스크린샷이 아니라 **앱 설명(description)**에 넣는다.
- 분류 메모: 2.3.7은 "metadata" 성격이지만, 스크린샷 가격문구는 **새 이미지가 필요**해 메타데이터 필드 PATCH(supportUrl/marketingUrl 등)로 자동수정 불가 → 이미지 재생성(사람/디자인) + 재업로드 + 재제출. autoFixable=false가 정답.

### L4. `[프로젝트:NeonNovel]` 스크린샷 재생성 절차와 함정
- 소스: `mobile/screenshots/template.html` (캡션 + 목업 HTML), 렌더러 `mobile/screenshots/capture.mjs` (Playwright, `#ss1..8` 요소를 `screenshot_1..8.png`로 @ viewport 1290×2796).
- **Playwright는 레포 의존성이 아니다.** `npm install playwright --prefix mobile` 는 실패한다 — `mobile/package.json`이 워크스페이스 패키지 `@novel-bot/shared@*`에 의존하는데 레지스트리에 없어 404. → **격리된 임시 디렉터리**(예: `/tmp/pw-gen`)에서 `npm init -y && npm install playwright` 후, 절대경로로 `template.html`을 렌더하는 러너를 실행한다. (Playwright **브라우저 바이너리**는 `~/Library/Caches/ms-playwright`에 이미 캐시돼 있어 재다운로드 불필요.)
- `#ss` 번호 ≠ ASC 표시 순서. 2026-05-25 기준 ASC iPhone 6.5"에는 7장 표시인데 템플릿은 8장 생성 → **업로드 슬롯 매핑을 반드시 확인**. (이때 거절 유발 캡션 #2="매일 새로운 소설, 무료로…"=`screenshot_2.png`, 마지막 슬롯="지금 무료로 첫 이야기를…"=`screenshot_8.png`였다.)
- 재생성 검증: 출력 PNG를 직접 열어 가격 문구가 사라졌는지 눈으로 확인(텍스트가 이미지에 래스터화되므로 grep 불가).
