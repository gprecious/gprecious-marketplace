# Loop Engineering 원칙

## 정의

이미 하네스가 있는 반복 업무를 **trigger · state · verification · human gate · stop condition**으로
감싸는 운영 설계층. prompt를 잘 쓰는 일이 아니라, agent가 다시 시도할 수 있는 **환경·검증·종료조건·
상태저장소**를 설계하는 일.

## 가장 큰 오해 (반드시 교정)

루프 엔지니어링은 **제품 전체를 자동 양산하는 공장이 아니다.** 제품에는 사람의 취향·우선순위·
risk appetite이 들어가므로, human gate 없이 모든 단계를 자동화하면 scope 대비 리스크를 판단하지
못한다. 많은 작업은 24/7 fleet이 아니라 single session + 좋은 prompt의 **solo loop**로 충분하다.

## 도입 판정 4기준 (triage)

후보 업무가 아래 4개를 **모두** 만족할 때만 루프로 만든다.

| 기준           | 질문                               | 탈락 예시          |
| -------------- | ---------------------------------- | ------------------ |
| `repetitive`   | 반복적으로 발생하는가?             | 1회성 마이그레이션 |
| `reviewable`   | 결과를 사람이 검토 가능한가?       | 검증 불가능한 창작 |
| `valuable`     | 가치 > token/time cost 인가?       | 月 1회·5분 수작업  |
| `bounded-risk` | 되돌릴 수 있고 폭발 범위가 좁은가? | prod DB 직접 변경  |

하나라도 불만족 → 루프 부적합. 단발 작업이면 goalcraft로, 큰 리스크면 사람이 직접.

## Human Gate 원칙

- **분석은 LLM에게, 결정은 사람에게.** issue 분석·코드베이스 조사·metadata 작성은 맡기되,
  진행 여부·scope 대비 가치·리스크 판단은 사람이 요약 리포트를 보고 결정한다.
- 모든 단계가 아니라 **scope가 넓거나 / 배포 영향이 크거나 / 주관적 product taste가 필요한** 지점에만.
- 반대로 no-op report·docs drift 확인·"에러 없음" 보고처럼 **결과가 좁고 되돌리기 쉬운** 루프는
  자동 종료 허용.
- **human gate 전에는 코드/문서 변경을 만들지 않는다** (진행 결정 전 변경 = 불필요한 diff).

## done criteria

objective metric에 가까울수록 좋다. 주관적 기준이면 반드시 **rubric + independent checker +
sample set + pass/fail threshold + hard cap**을 붙인다. "만족할 때까지"는 금지.
핵심 질문: _"What does done mean, and how will it check?"_
