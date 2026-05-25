# analyze-service codebase input — 설계 문서

- 날짜: 2026-05-25
- 상태: 설계 승인됨 — spec 리뷰 게이트 대기
- 대상 플러그인: `claude-plugins/growth-marketer/` (Plan 1 이 main 에 머지된 상태에서 확장)
- 선행 spec: `docs/superpowers/specs/2026-05-25-growth-marketer-design.md`

## 1. 목적

`analyze-service`(및 `/market`)가 서비스 URL 뿐 아니라 **로컬 코드베이스 디렉토리**를
입력으로 받아 서비스 프로파일·채널 추천을 만들 수 있게 한다. (git repo 클로닝은 범위
제외 — 로컬 디렉토리만.)

## 2. 입력 모델 (확정)

- 입력 자동 감지: **URL(web)** | **로컬 디렉토리 경로(local_dir)**.
  - `http(s)://...` → `source_type = "web"` → 기존 Claude-in-Chrome 읽기 경로.
  - 존재하는 디렉토리 경로 → `source_type = "local_dir"` → 코드베이스 파일 읽기(chrome 불필요).
- `source_type` 을 `service-profile.json` 에 기록.
- **VOC 조건부 필수**: `voc` 는 `source_type == "web"` 일 때만 필수, `local_dir` 이면 선택(비움 허용).
  - 이유: 코드베이스에는 고객 리뷰가 없다. `evidence`·`positioning`·`channel_signals` 는 두 소스 모두 필수 유지.

## 3. 데이터 계약 변경 (`schemas/service-profile.schema.json`)

- top-level `x-required` 에 `source_type` 추가. 제거: `voc` (무조건 필수에서 빠짐).
- `source_type` property: `{ "type": "string", "enum": ["web", "local_dir"] }`.
- 새 구문 `x-required-when` 추가 (top-level):
  ```json
  "x-required-when": [
    { "field": "voc", "when": { "source_type": "web" } }
  ]
  ```
  의미: `when` 의 모든 키=값이 artifact 와 일치하면 `field` 가 필수(존재 + non-null).
- `source_urls`(top-level) 및 `evidence[].source_url`·`voc[].source_url` 의 의미를
  "URL **또는 로컬 파일 경로**" 로 확장 — 필드명은 그대로 유지(churn 최소화), schema
  `description` 으로 명시.
- `positioning`(value_prop/category 필수), `evidence`(claim+source_url), `channel_signals`
  (product_type/market/price_model/target/discovery_intent 필수)는 변경 없음.

## 4. validator 변경 (`scripts/validate-artifact.sh`)

- 기존 3-pass(top-level x-required / nested object x-required / array item x-required-item)
  뒤에 **4번째 pass — 조건부 필수** 추가:
  - 스키마의 `x-required-when` 배열을 순회.
  - 각 규칙: `when` 객체의 모든 키에 대해 artifact 의 해당 값이 일치하는지 확인.
  - 모두 일치하면 `field` 가 존재하고 non-null 인지 검사. 누락 시
    `missing conditionally-required field: <field> (when <conditions>)` 출력 + error 카운트.
- generic 유지 — 스키마명·필드명 하드코딩 금지(`channel-scores` 등 다른 스키마에 무영향:
  `x-required-when` 없으면 pass 가 no-op).
- 종료 코드 규약(0 pass / 1 violation / 2 infra) 유지.

## 5. `analyze-service` skill 변경 (`SKILL.md`)

- **입력** 섹션: "내 서비스 URL **또는 로컬 코드베이스 디렉토리 경로**".
- **절차**:
  - step 1 에 source_type 자동 감지 추가(http(s)→web, 디렉토리 경로→local_dir).
  - step 2 분기: web = 기존 chrome 읽기. **local_dir(신규)** = chrome 없이 파일 읽기:
    README(.md)·`package.json`/`app.json`/`pubspec.yaml`/`Info.plist`/`manifest.json`·
    `docs/`·랜딩/마케팅 카피·소스 트리 구조.
    - 도출: `positioning`(value_prop/category/differentiators), `channel_signals`
      (product_type 는 manifest 로 추론 — expo/capacitor/flutter/ios/android→mobile_app,
      next/react/vite/web→web_saas; market/price_model/target/discovery_intent 는
      best-effort 추론), `icp`, `evidence`(각 주장 → 읽은 파일 경로).
    - `voc` 는 비움(선택).
  - service-profile 에 `source_type` 기록.
  - 검증 게이트 동일: `scripts/validate-artifact.sh service-profile <...>` 통과 필수.
- **데이터 계약/drift 규칙**·**출력**·**안전** 섹션은 유지(local_dir 은 파일시스템 읽기 전용).

## 6. `/market` 커맨드 + README

- `commands/market.md` 사용법: `/market <서비스 URL | 로컬 코드베이스 경로> [경쟁사 URL ...]`.
  - 트리거/설명에 코드베이스 입력 추가.
- skill description 트리거 문구에 "이 코드베이스/레포 분석해서 마케팅", "로컬 프로젝트 분석" 류 추가.
- plugin `README.md` 동작 설명에 local_dir 입력 추가. repo-root README 표 설명 필요 시 갱신.

## 7. Codex 미러 + 테스트

- deps 가 `skills/analyze-service/` 안에 있으므로, 변경된 SKILL·schema·validator·
  fixtures·tests 를 `.agents/plugins/plugins/growth-marketer/skills/analyze-service/` 로
  미러(skill 트리 복사). 두 위치에서 bats 통과.
- **테스트 추가**(`tests/validate-artifact.bats` + fixtures):
  - `service-profile.web.valid.json` (source_type=web, voc 있음) → 통과.
  - `service-profile.web-noVoc.invalid.json` (source_type=web, voc 없음) → 실패(조건부 필수).
  - `service-profile.localdir.valid.json` (source_type=local_dir, voc 없음) → 통과.
  - 기존 `service-profile.valid.json` 은 source_type 추가해 유지(또는 web fixture 로 대체).
  - `channel-scores` 테스트는 영향 없음(x-required-when 없음 → 4번째 pass no-op 확인).

## 8. 범위 밖 (YAGNI)

- git repo 클로닝/원격 호스트 읽기(gh/API) — 제외(로컬 dir 만).
- 코드베이스 정적 분석/의존성 그래프 심화 — README·manifest·구조 수준까지만.
- channel_signals enum 에 "unknown" 추가 — 하지 않음(local_dir 은 best-effort 추론).

## 9. 테스트/검증

- bats: web/local_dir/조건부 케이스 추가, 양 위치 통과.
- 두 marketplace JSON 유효성 유지.
- chrome E2E(web) 및 실제 로컬 디렉토리 스모크는 수동(HARD GATE) — 빌드 시 결정적
  레이어(스키마/validator/bats)만 자동 검증.
