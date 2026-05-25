---
description: 서비스 URL 을 분석하고 적합 마케팅 채널을 추천한다 (analyze-service 진입점)
---

# /market

사용법: `/market <서비스 URL> [경쟁사 URL ...]`

이 커맨드는 analyze-service skill 을 호출해 다음을 순서대로 수행한다:
1. 입력 URL(들)을 Claude-in-Chrome 으로 읽어 service-profile.json 작성.
2. channel-fit-rubric 으로 채널 점수·추천(channel-scores.json) 산출.
3. validate-artifact.sh 로 두 산출물 검증.
4. 추천 채널·근거 요약 + 저장 경로 보고.

이후 단계(카피 생성·플레이북·CRO 감사·draft 캠페인)는 별도 skill 로 이어간다.
인자가 없으면 사용자에게 서비스 URL 을 묻는다.
