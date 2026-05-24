# growth-marketer — 설계 문서 (v1)

- 날짜: 2026-05-25
- 상태: 설계 승인 대기 (사용자 리뷰 게이트)
- 위치: `claude-plugins/growth-marketer/` (in-repo 로컬 폴더, 워크플로 C)

## 1. 목적 / 배경

사용자가 만든 제품(모바일 B2C 앱 + 웹/SaaS)의 마케팅을 자동화하는 Claude Code
플러그인. 서비스를 분석하고, 적합 채널을 추천하고, 인지심리학 기반 카피·플레이북을
만들고, 연결된 브라우저로 광고 플랫폼에 캠페인 초안(draft)까지 자동 입력한다.
발행은 사람이 한다.

인지심리학·채널 방법론은 사전 research 로 baking(정적), 내 서비스·경쟁사 분석은
런타임 live(브라우저 + research-engine). → **하이브리드 지식 모델**.

## 2. 아키텍처 결정 (확정)

**접근법 A — skill-first / MCP-driven 플러그인.** SKILL 문서 + baked references +
data 파일. Claude Code 안에서 동작. 브라우저 자동화는 이미 연결된
Claude-in-Chrome MCP(`mcp__claude-in-chrome__*`) 사용. research 는
herdr + research-engine 으로 일회성 baking. 무빌드, 마켓 즉시 등록.

### 결정 근거 (claude + codex 독립 평가 합의)

A vs B(전용 Agent SDK/Vercel AI SDK 서비스) vs C(하이브리드)를 herdr 로 claude·
codex 두 세션에 독립 평가시킨 결과, 둘 다 **"v1 은 A 로 만들고 나중에 B 로 이주
가능하게 구조화"** 로 수렴:

- **브라우저 도달 범위가 결정타** — 앱스토어/리뷰 live 분석과 Meta/Google/Naver
  draft 입력은 봇 차단이 강함. A 는 사용자가 이미 로그인한 실제 브라우저 세션을
  그대로 타서 인증·anti-bot 문제가 사라짐. B(headless)는 세션/쿠키/봇회피를 직접
  재구현해야 하고 계속 깨짐.
- **과금 모델** — A 는 flat OAuth 구독 + 브라우저 로그인 재사용. B 는 종량 API
  key 라 long-context 반복 작업(리뷰 독해·카피 생성)에서 비용 예측 불가. 1인
  운영자엔 A.
- **능력 상한 동률** — 같은 Claude 모델. v1 기능은 B 의 빌드 비용을 정당화 못 함.
- **B 전환 트리거** — day-1 멀티테넌트 SaaS(타 창업자 판매, 무인 스케줄 실행,
  고객별 격리·과금)가 필요할 때만 B. 현재는 아님.

평가에서 공통으로 지적된 두 약점을 v1 에 격상 반영(§5, §6):
**(1) 데이터 계약 레이어, (2) draft-campaign 검증 게이트.**

## 3. 폴더 구조

```
claude-plugins/growth-marketer/
├── .claude-plugin/plugin.json     # name/version/description/author/keywords (auto-discovery)
├── README.md
├── commands/
│   └── market.md                  # 얇은 진입점: analyze → 추천 시퀀스
├── skills/
│   ├── analyze-service/SKILL.md    # 기능1: 서비스 분석 (ICP+VOC, live)
│   ├── generate-copy/SKILL.md      # 기능2: 인지심리학 기반 카피 (멀티 자산타입)
│   ├── channel-playbook/SKILL.md   # 기능3: 채널별 플레이북 (baked)
│   ├── cro-audit/SKILL.md          # 기능4: 전환 마찰 감사
│   ├── draft-campaign/SKILL.md     # 기능5: chrome 초안 자동입력 (검증 게이트)
│   └── review-assets/SKILL.md      # 기능6: 브랜드 보이스·일관성 QA 패스
├── references/                     # research 산출물 baking (정적 지식)
│   ├── cognitive-psychology/       # CTR·전환 기법 카탈로그
│   ├── frameworks/                 # 오퍼·value equation·hook·카피 공식
│   ├── channels/                   # meta/google-ads/naver/aso/seo 플레이북 소스
│   ├── channel-fit-rubric.md       # 서비스 속성 → 채널 점수 매핑
│   └── quality-standards.md        # "what good looks like" — review-assets 가 사용
└── data/
    ├── copy-templates.json         # 채널·자산타입별 포맷 제약·템플릿
    └── technique-index.json        # 기법 → 적용 채널/자산 매핑
```

`plugin.json` 은 `name/version/description/author/keywords` 만 사용(commands/skills/
agents 키 금지 — auto-discovery, CLAUDE.md 규칙 준수).

## 4. 기능별 skill 동작

전부 §5 의 데이터 계약(파일 산출물)을 따른다. 산출물은
`<프로젝트>/.growth-marketer/<service-slug>/` 아래에 버전드로 저장된다.

1. **`analyze-service`** (live, 하이브리드)
   - 입력: 내 서비스 URL(앱스토어 리스팅 / 랜딩페이지) + 선택적 경쟁사 URL.
   - `mcp__claude-in-chrome__*` 로 페이지·리뷰·소셜을 읽어 **ICP + VOC(고객의
     목소리) + 포지셔닝** 추출. 필요 시 research-engine `/research` 로 경쟁사·시장
     live 스캔.
   - 산출: `service-profile.json` (입력 스냅샷·source URL·추출 데이터 포함) +
     사람 읽는 `service-brief.md`.

2. **`generate-copy`** (baked + 프로파일)
   - 입력: `service-profile.json` + 타겟 채널 + 자산타입 + 기법 선택.
   - 자산타입: 광고/CTA · 랜딩페이지 카피 · 이메일(온보딩/라이프사이클) 시퀀스 ·
     오가닉 소셜. baked 인지심리학 카탈로그 + `copy-templates.json` 포맷 제약 적용.
   - 산출: `copy/<asset>-<channel>.md` — **각 카피에 사용 기법 주석**(기법 id,
     출처 참조) + A/B 변형. 설명·측정 가능.

3. **`channel-playbook`** (baked 표면화)
   - 입력: 채널 + `service-profile.json`.
   - `references/channels/<channel>.md` 를 서비스에 맞게 테일러링 → 실행
     플레이북(타겟팅·입찰·크리에이티브 규격·측정 KPI).
   - 산출: `playbook-<channel>.md`.

4. **`cro-audit`** (live + baked)
   - 입력: 랜딩/가입/페이월 URL.
   - 브라우저로 전환 퍼널을 읽어 마찰 지점 분석(폼 길이·CTA 명료성·신뢰 신호·
     로딩·모바일 등) → baked CRO 베스트프랙티스 대비 개선안.
   - 산출: `cro-audit-<page>.md` (마찰 항목 → 근거 → 우선순위 개선안).

5. **`draft-campaign`** (반자동, 검증 게이트 — §6)
   - 입력: `copy/*` + 크리에이티브 규격 + 채널.
   - Claude-in-Chrome 으로 플랫폼 캠페인 빌더 진입 → 필드를 **draft 로만** 입력.
   - 산출: `campaign-draft-<channel>.md` = 입력 전/후 스크린샷 + field map +
     draft diff + 확인 체크리스트. 발행 버튼 절대 클릭 금지.

6. **`review-assets`** (일관성 QA 패스)
   - 입력: 위 산출물 전체.
   - `quality-standards.md` 기준으로 브랜드 보이스·메시지·톤 일관성 검사 →
     불일치/약점 + 수정 제안.
   - 산출: `review-checklist.md`. **draft-campaign 발행 게이트의 일부**.

`/market` 커맨드는 analyze → 채널 추천까지 자동 시퀀스하는 얇은 진입점이며, 각
skill 은 독립 호출도 가능하다.

## 5. 데이터 계약 레이어 (신규 — 핵심)

모든 skill 은 채팅 출력이 아니라 **버전드 구조화 파일**을 산출한다. 이것이 동시에
세 가지를 해결한다: (a) 프롬프트 결과 drift 방지, (b) review-assets 패스의 입력,
(c) 나중 B(Agent SDK/Vercel) 이주 시 핵심 로직을 문서·데이터 계약으로 보존하는
seam.

### 저장 위치 / 버전

```
<project>/.growth-marketer/<service-slug>/
├── service-profile.json        # analyze-service (SoT)
├── service-brief.md
├── channel-scores.json         # 채널 적합도 스코어 + 추천 근거
├── copy/<asset>-<channel>.md
├── playbook-<channel>.md
├── cro-audit-<page>.md
├── campaign-draft-<channel>.md # 스크린샷·field map·diff
├── review-checklist.md
└── runs/<timestamp>/           # 각 실행 스냅샷 (재현·diff용)
```

### 계약 원칙

- **고정 스키마** — 자유문 금지. 각 산출물은 정해진 JSON/Markdown 섹션을 가진다
  (예: `service-profile.json` = `{source_urls, captured_at, icp, voc[], positioning,
  evidence[]}`).
- **출처 추적** — 모든 추출/주장에 source URL 또는 reference id 를 부착(fact-check
  가능). 인지심리학 주장은 research 출처 링크 보존.
- **단일 진실 공급원 + diff 갱신** — `service-profile.json` 이 SoT. live 재분석은
  통째 덮어쓰지 않고 `runs/<ts>/` 스냅샷 + 기존 대비 diff 로 갱신해 drift 추적.
- **이주 seam** — 비즈니스 로직은 references/rubrics + 이 데이터 계약에 있고 skill
  은 얇은 오케스트레이션. → 나중에 B 로 옮길 때 references·data·계약을 그대로
  재사용.

## 6. draft-campaign 검증 게이트 (신규 — 안전)

브라우저 멀티스텝 입력의 비결정성·실수 비용을 막는 발행 전 하드 게이트:

1. **발행 금지 하드룰** — `draft-campaign` 은 발행/게시/Publish 버튼을 절대 클릭
   하지 않는다. draft 저장까지만.
2. **dry-run 우선** — 기본은 입력할 field map 을 먼저 계획·출력하고, 사용자
   확인 후에만 실제 입력. 예산·결제 필드는 입력 전 개별 확인.
3. **스크린샷 read-back** — 입력 전/후 스크린샷을 캡처해 실제 채워진 값과 의도
   값을 대조(`campaign-draft-<channel>.md` 에 기록).
4. **확인 체크리스트 + 일관성 패스** — `review-assets` 의 `review-checklist.md`
   통과를 발행 게이트로 강제. 사람은 이 체크리스트와 스크린샷을 보고 발행 결정.

## 7. research 단계 (Phase A — 구현 시 herdr 병렬 fan-out)

herdr-orchestrator 로 N개 worker(claude + codex 혼합) spawn → 각 worker 가
research-engine `/research` 를 한 토픽씩 담당 → 결과를 종합해 `references/` 저작.

토픽 ~18개 (2 herdr tab, 3×3 grid + spillover):
- **채널(6)**: Meta Ads, Google Ads/UAC, Naver(검색·GFA), ASO, SEO/콘텐츠,
  리타게팅
- **인지심리학(8)**: Cialdini 6원칙, 손실회피·prospect theory, 앵커링·프라이밍,
  희소성·FOMO, 사회적 증거, 시각 위계·색채 CTR, 카피 공식(AIDA/PAS/FAB),
  A/B 실험 방법론
- **추가(4)**: CRO 베스트프랙티스(랜딩·가입·페이월·폼), VOC/ICP 리서치법,
  이메일 라이프사이클 시퀀스, 오퍼/포지셔닝 프레임워크(value equation·hook 등)

각 reference 는 출처 링크를 보존한다(§5 출처 추적). 종합·저작도 herdr-orchestrator
로 reference 묶음별 worker 분담해 병렬화 가능.

## 8. 엔드투엔드 데이터 흐름

```
사용자: /market <내 서비스 URL>
  └─ analyze-service ─→ service-profile.json + channel-scores.json (추천 채널·근거)
        │  (사용자가 채널 선택)
        ├─→ channel-playbook ─→ playbook-<channel>.md          [baked]
        ├─→ generate-copy   ─→ copy/<asset>-<channel>.md (기법 주석) [baked+프로파일]
        ├─→ cro-audit       ─→ cro-audit-<page>.md             [live+baked]
        ├─→ review-assets   ─→ review-checklist.md (일관성 게이트)
        └─→ draft-campaign  ─→ campaign-draft-<channel>.md (스크린샷·diff, 발행 X)
```
프로파일은 한 번 만들고 이후 skill 들이 재사용. 각 단계 독립 실행 가능.

## 9. 안전 / 가드레일

- **인증/과금(herdr 상속)** — 모델 호출은 OAuth/구독 CLI(`claude`/`codex`)만.
  `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` 등 과금 키·SDK 직접호출 금지.
- **chrome draft-only + 검증 게이트** — §6.
- **ToS/윤리** — 기법 카탈로그에 다크패턴 경계 명시(허위 희소성·기만 금지). 광고
  플랫폼 자동화는 ToS 준수 범위(draft) 내.
- **출처 추적** — §5. 인지심리학 주장은 research 출처 보존.

## 10. 범위 밖 (v2, YAGNI)

- 완전 자동 발행, 38-skill 식 마이크로 세분화.
- 비주얼 크리에이티브/썸네일 생성(기존 youtube-thumbnail skill 연계).
- 성과 대시보드 read · 자동 A/B 측정 루프.
- 외부 repo 분리, 멀티유저/SaaS화(= B 전환), CRM 자동화, 스케줄 무인 실행.
- 오프라인/로컬 비즈니스 채널 심화.

## 11. 테스트

접근법 A 라 무빌드:
- `data/*.json` 스키마 검증.
- `service-profile.json` 등 데이터 계약 산출물의 고정 스키마 검증(필수 섹션 존재).
- `channel-fit-rubric` 샘플 입력 → 예상 추천 케이스 몇 개를 fixture 로.
- SKILL 발동 evals 는 경량.

## 12. 미해결 / 후속

- 플러그인 최종 이름 확정(`growth-marketer` 제안).
- 데이터 계약 산출물 저장 루트(`.growth-marketer/`) 를 `.gitignore` 에 넣을지
  (서비스별 산출물은 사용자 작업물이므로 ignore 권장).
- research 토픽 18개의 worker 분배(2 tab) 세부.
