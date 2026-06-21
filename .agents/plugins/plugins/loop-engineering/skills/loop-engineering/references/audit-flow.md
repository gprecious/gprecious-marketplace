# /loop-audit 절차 (캐노니컬)

입력: registry 경로(기본 `docs/loops/registry.md`). 산출: `docs/loops/audit-<YYYY-MM-DD>.md`.
**읽기만 한다** — 코드/루프를 바꾸지 않는다. 결과가 없으면 no-op 리포트로 끝낸다.

## 1. 레지스트리 로드

registry.md를 읽어 등록 루프 목록을 만든다. 없으면 "등록된 루프 없음"으로 종료(no-op).

## 2. 루프별 점검

각 루프의 spec.md를 읽고:

- **완결성**: 5요소·가드레일 7종에 빈칸이 있으면 FLAG.
- **드리프트**: verification에 적힌 명령/경로, backend가 실제로 존재하는지 확인
  (예: `pnpm lint` 스크립트 존재, 참조 파일 존재). 없으면 FLAG.
- **stage 적정성**: `scheduled`인데 evidence가 빈약하거나 no-op precision 근거 없으면 FLAG(강등 권고).

## 3. 지표 집계

각 루프 evidence/ 로그에서 지표(`guardrails-and-metrics.md` 6종)를 집계 가능하면 집계.
특히 ops 루프는 **no-op precision**(전체 실행 중 정확한 "변경 없음" 비율)을 보고. 데이터 부족이면 명시.

## 4. 승격 판정

`dry-run` 루프 중 no-op precision·useful finding rate가 안정적이면 **`scheduled` 승격 후보**로
표시하고, 적합 backend 연결을 권고(backend-mapping.md). 단 승격은 사람 결정(human gate).

## 5. 리포트 작성

`docs/loops/audit-<date>.md`에:

- 요약(루프 수, FLAG 수, 승격 후보 수)
- 루프별 PASS/FLAG + 사유
- 액션 아이템(빈칸 채우기·드리프트 수정·승격/강등)
  변경 사항이 하나도 없으면 "all clear (no-op)"로 끝낸다 — no-op 보고도 정상 산출물이다.
