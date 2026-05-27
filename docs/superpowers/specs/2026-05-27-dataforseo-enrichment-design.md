# analyze-service DataForSEO enrichment — 설계 문서

- 날짜: 2026-05-27
- 상태: 설계 승인됨 — plan 작성 진행
- 대상 플러그인: `claude-plugins/growth-marketer/`, skill `analyze-service`
- 선행 spec: `docs/superpowers/specs/2026-05-25-analyze-service-codebase-input-design.md`

## 1. 목적

`analyze-service` 가 추론(best-effort)하던 `discovery_intent`·`channel_signals.market`·
경쟁사 `evidence`·채널 점수를 **DataForSEO 실측 데이터**(검색량 + Google/Naver SERP)로
보강한다. 코드/랜딩 1장 읽기로는 만들 수 없는 시장 증거를 더해 채널 추천의 근거를 높인다.

범위는 **DataForSEO 만**, **HTTP 직접 호출**(MCP 미사용), **Labs/Keywords + SERP 최소 세트**.

## 2. 인증 / 시크릿 (확정)

- 자격증명은 1Password 항목 `op://Employee/DataForSEO/{username,password}` (이미 존재, LOGIN 카테고리).
- 런타임 조회: `op read "op://Employee/DataForSEO/username"` / `.../password` (1Password 데스크톱
  통합 — 로그인된 어느 머신에서나 동작, 분배할 토큰 없음).
- DataForSEO 인증: HTTP Basic — `curl -u "$user:$pass"`.
- **평문 금지**: 키를 파일·로그·커밋·환경영속에 남기지 않는다. 스크립트는 셸 변수로만 보유,
  명령 트레이싱 비활성(`set +x`), 출력에 자격증명 미포함.
- OAuth-only 규칙(모델 과금 한정)과 무관 — SEO 데이터 API 키는 별개 범주이며 사용자 제공 시크릿.

## 3. 컴포넌트

### 3.1 `scripts/dataforseo.sh`
- 사용법: `dataforseo.sh <category-keyword> <market: kr|global|both> <out.json>`.
- 동작:
  1. `op read` 로 username/password 취득. 실패(미로그인/항목없음)면 **exit 3**(= enrichment 불가,
     호출자는 graceful skip).
  2. Live(sync) 호출 — 호출 상한 ≤ 4:
     - 검색량: `POST /v3/keywords_data/google_ads/search_volume/live`
       (body: `[{"keywords":["<kw>"],"location_code":<by market>,"language_code":<by market>}]`).
     - Google SERP 상위: `POST /v3/serp/google/organic/live/advanced`
       (body: `[{"keyword":"<kw>","location_code":<by market>,"language_code":...,"depth":10}]`).
     - Naver SERP 상위(market 가 kr|both 일 때만): `POST /v3/serp/naver/organic/live/advanced`.
  3. 응답에서 추출해 `out.json`(seo-enrichment 스키마) 작성:
     `query`, `markets[]`, `search_volume{value,source_url}`, `serp_competitors[]{domain,rank,url,market}`,
     `serp_features[]`, `captured_at`(UTC ISO8601).
  4. 네트워크/HTTP 오류(비-200, `status_code != 20000`)는 stderr 보고 + **exit 4**(호출자 skip).
- market→location/language 매핑: kr=South Korea/ko, global=United States/en. both=양쪽(Google 은 us+kr,
  Naver 는 kr). 정확한 location_code 는 plan 에서 핀.

### 3.2 `schemas/seo-enrichment.schema.json`
- 기존 generic validator(`validate-artifact.sh`)로 검증 — **검증기 코드 변경 없음**.
- top-level `x-required`: `["query","markets","search_volume","serp_competitors","captured_at"]`.
- `search_volume` 객체 `x-required`: `["value","source_url"]`.
- `serp_competitors` 배열 `items.x-required-item`: `["domain","rank","source_url"]`.
- `serp_features` 는 선택(있으면 string 배열).

### 3.3 `references/serp-to-channel.md`
- SERP feature/검색량 → 채널 가중 규칙(예: shopping/PLA 존재→커머스 광고, local_pack→지역/지도,
  video→YouTube, 검색량 high→SEO/SEM 우선). `channel-fit-rubric.md` 를 보완.

## 4. analyze-service 통합 (graceful, opt-in)

SKILL.md 절차에 단계 추가(소스 읽기 후, 채널 스코어링 전):

- **SEO enrichment (선택)**: `op` 사용 가능 + DataForSEO 항목 존재 시
  `scripts/dataforseo.sh <positioning.category 또는 핵심 키워드> <market> <slug-dir>/seo-enrichment.json` 실행.
  - 성공(exit 0): `seo-enrichment.json` 을 검증(`validate-artifact.sh seo-enrichment ...`) 후
    - `service-profile.json.evidence[]` 에 항목 추가(claim=SERP/검색량 사실, source_url=DataForSEO endpoint).
    - `channel_signals.discovery_intent` 를 검색량 기준으로 **재산정**(임계값은 rubric).
    - `channel_signals.market` 를 Google vs Naver 상위결과 우세로 보정.
    - 경쟁사 SERP 도메인을 `positioning.differentiators`/evidence 비교에 반영.
  - 불가(exit 3/4 또는 op 없음): **skip** — 기존 Chrome/codebase 추론 그대로. skill 은 키 없이도 완주.
- `service-profile.json` 에 enrichment 사용 여부 흔적 남김: evidence 의 source_url 로 구분(별도 플래그 불필요).

## 5. 비용 가드

- 분석 1건당 Live 호출 ≤ 4 (검색량 1 + Google SERP 1 + Naver SERP 1, 여유 1). 키워드 1개(카테고리)만.
- 스크립트가 키워드 수를 1로 cap. 다중 키워드/배치는 범위 밖(YAGNI, 후속 C안).

## 6. 테스트

- bats(`tests/validate-artifact.bats` 확장):
  - `seo-enrichment.valid.json` fixture → validator 통과.
  - `seo-enrichment.invalid.json`(필수 누락) → 실패 + 누락 필드 메시지.
- `dataforseo.sh` 파싱 단위 테스트: **라이브 호출 없이** fixture DataForSEO 응답(JSON)을 입력으로
  주입해 추출 로직이 올바른 `seo-enrichment.json` 을 만드는지 검증.
  - 이를 위해 스크립트는 응답 파싱을 별도 함수/모드로 분리하거나, `DFS_FIXTURE_DIR` 환경변수로
    curl 대신 fixture 파일을 읽도록(테스트 주입 seam). 실제 키/네트워크 불필요.
- 라이브 스모크(검색량 1 + SERP 1 실제 호출)는 **수동 HARD-GATE**(`op` 로그인 필요) — 빌드 자동
  검증은 결정적 레이어(스키마·파싱·bats)만.

## 7. Codex 미러 + 마케팅 카탈로그

- 변경된 skill 트리(`scripts`/`schemas`/`references`/`tests`/`SKILL.md`)를
  `.agents/plugins/plugins/growth-marketer/skills/analyze-service/` 로 미러(rm -rf + cp -R). 양쪽 bats 통과.
- plugin.json 변경 없음(`mcpServers` 미사용, auto-discovery). marketplace.json 변경 없음(기능 확장).
- 작업 종료 시 `git push origin main` (CLAUDE.md HARD RULE).

## 8. 범위 밖 (YAGNI)

- MCP 서버 연동(`mcpServers`) — HTTP 직접만.
- task 기반 비동기(POST→poll)·다중 키워드 배치 — 후속.
- Ahrefs, App Data, Backlinks, On-Page, Content Analysis API — 이번 범위 밖.
- 다중 키워드/경쟁사 도메인 대량 분석.

## 9. 보안 요약

- 키: `op read` 런타임 조회만, 평문 미저장/미커밋/미로그.
- 호출: 읽기 전용 데이터 조회(발행·쓰기 없음). 모델 호출은 기존대로 OAuth CLI.
- graceful degradation 으로 키 미보유 환경에서도 안전 동작.
