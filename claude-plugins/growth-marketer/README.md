# growth-marketer

내 제품(모바일 앱·웹/SaaS)의 마케팅을 자동화하는 Claude Code 플러그인.
서비스 분석(ICP·VOC) → 채널 추천 → (이후 plan) 카피·플레이북·CRO·draft 캠페인.

## v1 (Plan 1) 제공 기능
- `/market <서비스 URL | 로컬 코드베이스 경로>` — 서비스 분석 + 채널 추천.
- `analyze-service` skill — 연결된 브라우저(web)로 페이지·리뷰를 읽거나 로컬 코드베이스
  파일(README·manifest·docs)을 읽어 구조화 프로파일 + 채널 스코어 산출(입력 자동 감지).
  결과는 `.growth-marketer/<slug>/` 에 저장(데이터 계약 준수).

## 동작 원리
- skill-first / MCP-driven (무빌드). 브라우저 자동화는 연결된 Claude-in-Chrome MCP.
- 산출물은 `skills/analyze-service/schemas/` 의 데이터 계약을 따르고 `skills/analyze-service/scripts/validate-artifact.sh` 로 검증.
- 채널 추천 근거는 `skills/analyze-service/references/channel-fit-rubric.md`.

## 안전
- 모델 호출은 OAuth/구독 CLI 만(과금 API 키 금지).
- 이 단계는 읽기 전용(브라우저 입력/발행 없음).

## 테스트
```bash
bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
```

## 로드맵
- Plan 2: research → references/ baking (인지심리학·채널 방법론).
- Plan 3: generate-copy / channel-playbook / cro-audit.
- Plan 4: draft-campaign(검증 게이트) / review-assets.
