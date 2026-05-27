---
name: analyze-service
description: |
  내 서비스를 분석해 ICP + VOC(고객의 목소리) + 포지셔닝을 추출하고 적합 마케팅 채널을
  점수·근거로 추천한다. 입력은 (1) 서비스 URL(앱스토어/랜딩페이지, 연결된 브라우저로 읽음)
  또는 (2) 로컬 코드베이스 디렉토리 경로(README·manifest·docs 를 읽음) 둘 다 가능 — 자동 감지.
  "내 서비스 분석", "마케팅 채널 추천해줘", "이 앱 어디에 광고하지", "ICP 뽑아줘",
  "이 코드베이스/레포 분석해서 마케팅", "로컬 프로젝트 분석" 같은 요청에 발동.
  "검색량·SERP 로 채널 근거 보강" 류 요청에도 DataForSEO enrichment 로 대응한다.
  결과는 .growth-marketer/<slug>/ 아래 구조화 파일로 저장된다.
---

# analyze-service

서비스 URL 또는 로컬 코드베이스를 읽어 구조화된 서비스 프로파일과 채널 추천을 만든다.
모든 산출물은 데이터 계약(schemas/)을 따르고 validate-artifact.sh 로 검증한다.

## 입력
- 필수: 내 서비스 **URL**(앱스토어 리스팅/랜딩페이지) **또는 로컬 코드베이스 디렉토리 경로** 중 하나.
- 선택: 경쟁사 URL 목록.

## 절차
1. **slug + source_type 결정** — 서비스명에서 kebab-case slug. 입력 자동 감지:
   `http(s)://...` → `source_type="web"`; 존재하는 디렉토리 경로 → `source_type="local_dir"`.
   산출 루트: `<repo-root>/.growth-marketer/<slug>/` (.growth-marketer/ 는 repo 루트 기준;
   사용자 프로젝트 .gitignore 에 .growth-marketer/ 가 없으면 추가한다). `runs/<ISO8601>/`
   스냅샷 디렉토리도 만든다 (UTC·초단위, 예: 2026-05-25T09:00:00Z).
2. **소스 읽기 (source_type 분기)**
   - **web**: `mcp__claude-in-chrome__*` 로 메인 리스팅/랜딩(가치제안·카테고리·기능·가격)과
     리뷰/소셜(실제 사용자 문장 VOC + source URL)을 읽는다. 봇 차단 회피를 위해 사용자의
     실제 로그인 세션을 그대로 사용(headless 금지).
   - **local_dir** (브라우저 불필요): 디렉토리에서 README(.md), `package.json`/`app.json`/
     `pubspec.yaml`/`Info.plist`/`manifest.json`, `docs/`, 랜딩·마케팅 카피, 소스 트리 구조를
     읽는다. product_type 은 manifest 로 추론(expo/capacitor/flutter/ios/android→mobile_app,
     next/react/vite/web→web_saas). market/price_model/target/discovery_intent 는 best-effort
     추론. VOC 는 코드에 없으므로 비운다(선택).
3. **경쟁사 (선택, live)** — 경쟁사 URL 이 있으면 동일하게 읽고, 더 깊은 시장 스캔이 필요하면
   research-engine `/research` 를 호출한다. 경쟁사에서 얻은 사실은 service-profile.json 의
   evidence[](source_url 포함) 와 positioning.differentiators 에 반영한다(별도 파일 없음).
4. **SEO enrichment (선택, DataForSEO — graceful)** — `op` CLI 가 있고 1Password 에
   `op://Employee/DataForSEO/{username,password}` 가 있으면 실행한다. positioning.category
   또는 핵심 카테고리 키워드를 쿼리로, market(kr|global|both)을 골라:
   ```bash
   bash skills/analyze-service/scripts/dataforseo.sh "<카테고리 키워드>" <kr|global|both> <slug-dir>/seo-enrichment.json
   ```
   - exit 0: `bash skills/analyze-service/scripts/validate-artifact.sh seo-enrichment <slug-dir>/seo-enrichment.json` 로 검증한 뒤
     `references/serp-to-channel.md` 규칙으로 `discovery_intent`(검색량)·`market`(Google vs Naver 우세)를
     **실측 기반 재산정**하고, 경쟁사 SERP 도메인을 evidence/differentiators 비교에 반영한다.
   - exit 3(자격증명/op 없음) 또는 exit 4(네트워크/API 오류): **skip** — 기존 추론값을 그대로 둔다.
     skill 은 키 없이도 완주한다.
5. **service-profile.json 작성** — `schemas/service-profile.schema.json` 스키마대로:
   `source_type`, icp(segment/pains/goals), positioning(value_prop/category/differentiators),
   evidence[](claim+source_url — URL·로컬 파일 경로·DataForSEO endpoint), channel_signals(product_type/market/
   price_model/target/discovery_intent). `voc[]`(quote+source_url)는 **source_type=web 일 때만
   필수**, local_dir 이면 비운다. enrichment 가 있었으면 그 사실은 evidence 의 DataForSEO source_url 로 표현한다.
6. **채널 스코어링** — `references/channel-fit-rubric.md` + (enrichment 있으면) `references/serp-to-channel.md`
   규칙으로 각 채널 0~5 점 + rationale, recommendation(primary/secondary/why) 산출 → `channel-scores.json`
   (`schemas/channel-scores.schema.json` 준수).
7. **service-brief.md 작성** — 사람이 읽는 요약(프로파일 핵심 + 추천 채널 + 근거 + enrichment 사용 여부).
8. **검증 (필수 게이트)** — 산출물을 검증한다. 실패하면 누락 필드를 채워 다시 저장.
   검증기·스키마·rubric 은 이 skill 폴더(skills/analyze-service/) 안에 있다 — Claude/Codex 양쪽 동일 상대경로.
   ```bash
   bash skills/analyze-service/scripts/validate-artifact.sh service-profile <slug-dir>/service-profile.json
   bash skills/analyze-service/scripts/validate-artifact.sh channel-scores  <slug-dir>/channel-scores.json
   # enrichment 을 수행했으면 그것도:
   bash skills/analyze-service/scripts/validate-artifact.sh seo-enrichment  <slug-dir>/seo-enrichment.json
   ```
9. **보고** — 추천 채널과 근거를 자연어로 요약하고, 저장된 파일 경로를 알린다.
   enrichment 을 skip 했으면 그 사실(자격증명 없음 등)을 명시한다.

## 데이터 계약 / drift 규칙
- `service-profile.json` 이 단일 진실 공급원(SoT). 재분석 시 통째 덮어쓰지 말고
  `runs/<ts>/` 에 스냅샷을 남기고 SoT 대비 diff 를 brief 에 기록한다.
- 자유문 산출 금지 — 항상 스키마 섹션을 채운다.

## 출력
- `.growth-marketer/<slug>/service-profile.json` (SoT)
- `.growth-marketer/<slug>/service-brief.md`
- `.growth-marketer/<slug>/channel-scores.json`
- `.growth-marketer/<slug>/seo-enrichment.json` (DataForSEO enrichment 수행 시에만)
- `.growth-marketer/<slug>/runs/<ts>/` 스냅샷

## 안전
- web 은 chrome 읽기 전용, local_dir 은 파일시스템 읽기 전용, DataForSEO 는 읽기 전용 데이터 조회
  (이 skill 은 외부에 입력/발행하지 않음).
- DataForSEO 자격증명은 `op read` 런타임 조회만 — 평문 저장/커밋/로그 금지. 키가 없으면 enrichment 만 skip.
- 모델 호출은 OAuth/구독 CLI 만, 과금 API 키 금지(마켓 정책). SEO 데이터 API 키는 별개 범주의 사용자 시크릿.
- 다음 단계(generate-copy/channel-playbook/cro-audit)는 이 산출물을 입력으로 받는다.
