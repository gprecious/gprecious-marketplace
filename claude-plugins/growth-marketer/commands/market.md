---
description: 서비스 URL 또는 로컬 코드베이스를 분석하고 적합 마케팅 채널을 추천한다 (analyze-service 진입점)
---

# /market

사용법: `/market <서비스 URL | 로컬 코드베이스 경로> [경쟁사 URL ...]`

이 커맨드는 analyze-service skill 을 호출해 다음을 순서대로 수행한다:
1. 입력을 자동 감지 — URL 이면 Claude-in-Chrome 으로, 로컬 디렉토리 경로면 코드베이스
   파일(README·manifest·docs)을 읽어 service-profile.json(`source_type` 포함) 작성.
2. channel-fit-rubric 으로 채널 점수·추천(channel-scores.json) 산출.
3. validate-artifact.sh 로 두 산출물 검증.
4. 추천 채널·근거 요약 + 저장 경로 보고.

이후 단계(카피 생성·플레이북·CRO 감사·draft 캠페인)는 별도 skill 로 이어간다.
인자가 없으면 사용자에게 서비스 URL 또는 코드베이스 경로를 묻는다.
