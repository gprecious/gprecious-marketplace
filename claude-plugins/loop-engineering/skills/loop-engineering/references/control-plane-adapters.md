# Control Plane 어댑터

루프의 state·evidence·gate를 어디서 inspect 하는가. `spec.md` 형식은 동일하고, **미러링 대상만** 바꾼다.

| 어댑터          | state 위치                         | 언제                                                                    |
| --------------- | ---------------------------------- | ----------------------------------------------------------------------- |
| **file** (기본) | 소비 repo `docs/loops/` (git 커밋) | 제품 비종속·버전관리·최고 이식성. 항상 기본.                            |
| github-issue    | GitHub Issue (label/comment)       | intake→gate→ship이 PR과 직결될 때. owner=gprecious/qplace-company 확인. |
| slack-relay     | Slack 스레드 (prime-orchestrator)  | 사람 게이트가 빠른 응답 필요. 기존 relay 인프라 재사용.                 |

## file (기본) 레이아웃

```
docs/loops/
  registry.md                 # 등록 루프 목록 1행/루프
  <loop-name>/
    spec.md                   # 5요소·가드레일·지표·backend·gate
    evidence/<run-id>.md      # 실행 증거 (no-op report 포함)
```

## 어댑터는 미러일 뿐

file이 항상 진실 공급원(SoT). github-issue/slack-relay는 같은 spec을 사람이 보기 쉬운 곳에
**복제**하는 것. 어댑터를 켜도 `docs/loops/`는 계속 커밋한다.
