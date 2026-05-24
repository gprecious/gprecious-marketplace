# Cross-pane chat (자문 + 능동 보고 채널)

당신이 다른 페인 (예: plan, dev, review) 에게 짧은 자문을 요청하거나, **작업 완료를 orchestrator 에 능동 보고**할 때의 규약. orchestrator 가 부트스트랩 메시지에 페인 매핑 (workspace ref + surface ref) 을 같이 줬으니, 그 매핑대로 호출한다.

## 두 가지 사용 케이스

### 1. 자문 (peer 페인 간)

- 다른 페인이 산출한 결정의 근거 한 줄 질의
- 모호한 AC 의 해석 자문
- 본인이 작성한 산출물에 대한 sanity check 요청

### 2. 능동 보고 (페인 → orchestrator)

- 작업 완료 + self-verify 직후 결과 한 줄 보고
- blocker 발생 시 한 줄 보고 후 대기

## 사용 금지

- 다른 페인에 작업 위임 (각 페인 역할 분리)
- destructive 명령 요청
- 사용자 모르게 장기 대화

## 절차 (자문)

1. 상대 페인이 작업 중인지 확인:

   ```bash
   cmux read-screen --workspace {pane_ws_ref} --surface surface:N --lines 20
   ```

   capture 가 빠르게 변하면 작업 중. 끼어들지 말 것.

2. 대상이 idle 이면 메시지 전송 (반드시 본인이 누구인지 한 줄 식별, **`--workspace` 명시 필수**):

   ```bash
   cmux send --workspace {pane_ws_ref} --surface surface:N "[from {your-role} pane] 짧은 질문 본문"
   cmux send-key --workspace {pane_ws_ref} --surface surface:N Enter
   ```

   `send-key Enter` 빼먹으면 입력만 들어가고 제출 안 됨. `--workspace` 빼면 surface 가 다른 ws 와 ambiguity.

3. 응답 폴링:

   ```bash
   prev=""
   for i in 1 2 3 4 5; do
     sleep 4
     cur=$(cmux read-screen --workspace {pane_ws_ref} --surface surface:N --lines 60)
     [ "$cur" = "$prev" ] && break
     prev=$cur
   done
   echo "$cur"
   ```

4. 응답 본문에서 모델 footer 와 입력 프롬프트 라인 제외하고 본문만 읽음.

## 절차 (능동 보고)

작업이 끝나면 orchestrator 페인에 한 줄 보고. 자문과 동일 메커니즘이지만 응답 폴링 없음 — 보고 후 idle 대기.

```bash
cmux send --workspace {orch_ws_ref} --surface surface:{N0} \
  "[from {your-role}] {your-role} done. artifact: <path> ({size}). self-verify: <ok|partial:사유>. <한 줄 추가 컨텍스트>"
cmux send-key --workspace {orch_ws_ref} --surface surface:{N0} Enter
```

`{orch_ws_ref}` 와 `surface:{N0}` 는 부트스트랩 메시지의 페인 매핑 표 참조 (보통 페인이 spawn 된 workspace 와 다른 곳에 orchestrator 가 있음).

orchestrator 가 자체 polling 도 하므로 보고 묵살되어도 작업이 회수됨. 단 능동 보고가 있으면 다음 단계가 즉시 진행되어 시간 절약.

## 토큰 예산

자문 1회 = 보통 200~500 토큰. 자문이 4번 이상이면 작업 분담을 잘못한 것 — orchestrator 에게 한 줄 보고하고 흐름 재정비 요청.
