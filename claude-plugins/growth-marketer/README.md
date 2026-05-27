# growth-marketer

내 제품(모바일 앱·웹/SaaS)의 마케팅을 자동화하는 Claude Code 플러그인.
서비스 분석(ICP·VOC) → 채널 추천 → 카피·플레이북·CRO 감사 → 일관성 QA → 캠페인 draft(발행 X).

## 제공 기능 (skill 6종 + 커맨드)
- `/market <서비스 URL | 로컬 코드베이스 경로>` — 서비스 분석 + 채널 추천 진입점.
- `analyze-service` — 연결된 브라우저(web)로 페이지·리뷰를 읽거나 로컬 코드베이스(README·manifest·docs)를
  읽어 구조화 프로파일 + 채널 스코어 산출(입력 자동 감지). (선택) DataForSEO HTTP enrichment 으로
  검색량·Google/Naver SERP 를 더해 채널 근거를 실측 보강 — 자격증명은 1Password(op), 없으면 자동 skip.
- `channel-playbook` — `service-profile.json` 기반으로 선택 채널의 운영 플레이북(타겟팅·입찰·크리에이티브·KPI)
  을 baked 채널 reference 에서 테일러링.
- `generate-copy` — 인지심리 기반 카피(광고/CTA·랜딩·이메일 시퀀스·오가닉)를 생성하고 각 변형에
  technique id + 출처를 주석. dark-pattern(허위 희소성 등)은 범위 밖으로 명시.
- `cro-audit` — 랜딩·가입·폼·페이월을 브라우저로 읽기 전용 점검해 전환 마찰 → 근거 → 우선순위 개선안.
- `review-assets` — 산출물 전체의 브랜드 보이스·메시지·claim/evidence 일관성을 `quality-standards.md` 대비
  QA. `review-checklist`(`gate_status`)는 draft-campaign 의 발행 게이트.
- `draft-campaign` — Claude-in-Chrome 으로 광고 플랫폼에 캠페인을 **draft 로만** 입력(발행 절대 금지).
  field map dry-run + 스크린샷 read-back + review-checklist=pass 게이트.

모든 산출물은 `.growth-marketer/<slug>/` 아래 데이터 계약(스키마)대로 저장된다.

## 동작 원리
- skill-first / MCP-driven (무빌드). 브라우저 자동화는 연결된 Claude-in-Chrome MCP.
- 각 skill 은 자기완결: `skills/<skill>/schemas/` 데이터 계약 + `scripts/validate-artifact.sh`(제네릭 검증기,
  `x-required`/`x-required-item`/`x-required-when` 힌트) + `references/`(baked 지식) + `tests/`(bats).
- 인지심리·채널·CRO 방법론은 사전 research 로 baking(정적), 내 서비스·경쟁사 분석은 런타임 live.

## 안전
- 모델 호출은 OAuth/구독 CLI 만(과금 API 키 금지). SEO 데이터 API 키(DataForSEO)는 별개 범주의 사용자 시크릿.
- 읽기 전용 분석 + draft 전용 입력. `draft-campaign` 은 발행/게시 버튼을 절대 클릭하지 않는다(스키마·테스트로 강제).

## 테스트
```bash
for d in claude-plugins/growth-marketer/skills/*/tests/validate-artifact.bats; do bats "$d"; done
```

## Codex 미러
각 skill 트리는 `.agents/plugins/plugins/growth-marketer/skills/<skill>/` 로 1:1 미러된다(repo invariant).
