---
name: cmux-pane-chat
description: "cmux 워크스페이스 안의 다른 터미널 패널(codex, 다른 claude 세션, 일반 shell)에 메시지를 보내고 응답을 읽기 위해 사용. \"옆 패널\", \"다른 패널\", \"codex 에게\""
---

# cmux 패널 간 소통

cmux 는 macOS 멀티터미널 앱이고, 한 워크스페이스 안에 여러 패널(surface)을 띄워 각각에서 다른 프로세스(예: claude code, codex, 일반 shell)를 돌릴 수 있다. `cmux` CLI 가 Unix socket 으로 그 패널들을 제어해서, 입력을 주입하고 화면을 뜯어보는 식으로 옆 패널의 agent 와 협업할 수 있다.

이 skill 은 그 워크플로우를 표준화한다.

## 언제 쓰는가

- 옆 패널의 codex 한테 코드 리뷰/대안 제시를 요청하고 응답을 받고 싶을 때
- 다른 패널에 켜진 일반 shell 에서 명령을 돌리고 싶지 않고, 그 패널이 자체적으로 가진 컨텍스트(예: 이미 ssh 연결, 가상환경 활성, 특정 디렉토리)를 활용하고 싶을 때
- 두 AI agent 가 같은 코드베이스를 두고 의견을 교환하게 하고 싶을 때

## 사전 점검

먼저 한 번만 다음을 확인한다 — 둘 다 통과해야 진행할 수 있다.

```bash
echo "$CMUX_SOCKET_PATH"   # 비어있지 않아야 함
which cmux                  # /Applications/cmux.app/.../bin/cmux 가 떠야 함
```

비어있으면 이 skill 은 동작하지 않는다 — 사용자에게 "cmux 환경이 아닌 것 같다"고 알리고 중단.

## 핵심 명령 4종 (이게 전부다)

| 목적                    | 명령                                               |
| ----------------------- | -------------------------------------------------- |
| 패널 구조 확인          | `cmux tree`                                        |
| 화면 읽기               | `cmux capture-pane --surface surface:N --lines 40` |
| 텍스트 전송             | `cmux send --surface surface:N "메시지"`           |
| 키 전송 (Enter, Tab 등) | `cmux send-key --surface surface:N Enter`          |

**중요한 함정**: `send-panel --panel pane:N` 형태는 `Surface is not a terminal` 에러를 낸다. 반드시 **`--surface surface:N`** 으로 surface ID 를 직접 지정해야 한다. `cmux tree` 출력에서 `surface surface:8 [terminal]` 처럼 보이는 ID 를 그대로 쓴다.

## Workspace / Pane 식별 검증 (필수)

이 skill 은 옆 패널과 단발 통신용이지만, 같은 window 안에 비슷한 surface 가 여러 개 있어 **잘못된 패널에 메시지를 보내는 사고가 자주 난다**. 매 send 직전에 다음 4단계를 반드시 통과한다.

1. **`cmux tree` 로 대상 식별**: focused (`◀ here`) pane 은 절대 send 대상이 아니다. 사용자가 지칭한 패널의 surface ID 를 정확히 골라낸다. 후보가 여러 개면 capture 로 한 번 더 식별.
2. **`cmux capture-pane --surface surface:N --lines 5` 로 sanity 확인**: 그 surface 가 정말 사용자가 말한 agent (codex/claude/shell) 인지 화면 단서로 검증. 단서가 모호하면 **send 중단** 후 사용자에게 어떤 surface 인지 확인.
3. **`--workspace workspace:M --surface surface:N` 풀 명시**: workspace 옵션 생략 시 cmux 가 ambiguity 로 silent 하게 다른 workspace 에 메시지를 흘릴 수 있다. 새 workspace 가 여러 개 떠 있는 환경(`cmux-orchestrator` 와 병행)에서 특히 위험.
4. **send 직전 한 줄 trace**: `send: workspace:M surface:N — captured tag: '<짧은 화면 단서>'` 를 본인 출력에 남긴다. 사고 발생 시 이 로그로 송신 기록 추적 가능.

검증 실패(focused pane 이거나 화면 단서가 다름) 시 send 를 중단하고 사용자 확인. 잘못 보내진 메시지는 상대 패널의 컨텍스트를 오염시킨다는 점을 잊지 말 것.

## 표준 워크플로우

### 1단계 — 대상 패널 식별

```bash
cmux tree
```

출력 예시:

```
window window:1 [current]
├── workspace workspace:1
│   ├── pane pane:1
│   │   └── surface surface:2 [terminal] "tmux new-session -s claude"
│   ├── pane pane:2 [focused] ◀ here
│   │   └── surface surface:1 [terminal] "현재 작업 제목"
│   └── pane pane:7
│       └── surface surface:8 [terminal] "tmux new-session -s qplace"
```

`◀ here` 는 현재 본인이 떠있는 패널 — 이건 건드리지 않는다. 나머지 surface 후보들 중 사용자가 말한 패널이 어느 것인지 애매하면 각 surface 의 마지막 화면을 살짝 잡아본다:

```bash
cmux capture-pane --surface surface:8 --lines 15
```

화면 텍스트로 무엇이 돌고 있는지 판별:

- `gpt-5.x` 또는 `Codex` 프롬프트 → codex
- `Claude` / `claude.ai` 프롬프트, `Opus`/`Sonnet` 모델명 → claude code
- `$ `, `% `, `(venv) `, `git status` 같은 출력 → 일반 shell

### 2단계 — 메시지 전송

```bash
cmux send --surface surface:8 "여기에 보낼 본문"
cmux send-key --surface surface:8 Enter
```

두 번째 줄을 빼먹으면 입력만 들어가고 제출이 안 돼서 응답이 절대 안 온다 — 항상 짝으로 호출.

CLI 답게 따옴표 이스케이프에 주의. 본문이 길거나 줄바꿈/특수문자가 많으면 heredoc 보다 임시 파일에 적고 `--text-file` 같은 옵션을 찾기보다는 그냥 큰따옴표 + `\n` 변환 없이 그대로 보낸다 (cmux send 는 multi-line 텍스트 그대로 받음).

만약 메시지에 큰따옴표가 들어가야 한다면 작은따옴표로 감싸거나 `\"` 로 이스케이프.

### 3단계 — 응답 폴링 & capture

상대 agent 가 답하는 데 걸리는 시간은 케이스마다 다르다. 첫 시도는 짧게, 안 끝났으면 더 기다린다.

```bash
sleep 4
cmux capture-pane --surface surface:8 --lines 60
```

응답이 끝났는지 판별하는 휴리스틱:

- codex: `gpt-5.x · ~/...` 같은 footer 가 다시 보이고, 그 위에 `›` 입력 프롬프트가 비어 있으면 답변 종료
- claude: `─── ❯ ───` 입력 프롬프트가 비어있고 모델 footer 가 보이면 종료
- 답변 중간에는 보통 토큰이 증가하면서 화면이 바뀜 — 같은 화면을 두 번 capture 했을 때 동일하면 (raw bytes 비교) 멈춘 것

긴 응답을 기다릴 때 (최대 ~60초 정도까지):

```bash
prev=""
for i in 1 2 3 4 5 6; do
  sleep 5
  cur=$(cmux capture-pane --surface surface:8 --lines 60)
  [ "$cur" = "$prev" ] && break
  prev=$cur
done
echo "$cur"
```

그 이상 걸리면 사용자에게 한 번 보고하고 계속 기다릴지 물어본다. 무한 폴링은 금지 — 상대가 멈췄거나 입력 대기 상태일 수 있다.

### 4단계 — 결과 정리

capture 한 화면에서 답변 본문만 추출해서 사용자에게 전달한다. capture 결과에는 footer, 입력 프롬프트, ANSI 잔재가 섞여 있으므로:

- 마지막 입력 프롬프트(`›` 또는 `❯`) 위쪽이 답변 본문
- 본인이 보낸 질문 라인 아래 `•` 또는 `⏺` 같은 응답 마커가 답변 시작점
- 모델 footer 줄(`gpt-5.x ...`, `claude X.X.X`)은 잘라낸다

본인의 메시지에 답변을 그대로 인용해서 사용자에게 보여주는 게 좋다. "codex 가 이렇게 답했어:" + 본문.

## 협업 패턴 예시

**A. 단발 질의** — 가장 흔함. 한 번 묻고 한 번 받음.

**B. 의견 교환** — 사용자가 "codex 와 의논해서 결론 내" 같은 요구를 할 때:

1. 본인이 먼저 안을 짠다
2. codex 에게 안을 보내고 비판/대안을 요청
3. 응답을 받아 사용자에게 양쪽 주장을 정리해서 보여준다
4. 사용자가 결정하게 한다 — 본인이 임의로 codex 안을 채택하거나 무시하지 말 것. 사용자는 두 agent 의 비교 자체를 보고 싶어하는 경우가 많다.

**C. 분업** — 같은 task 의 다른 부분을 codex 에게 맡기고 본인은 다른 부분 진행. 이 경우 메시지를 넘길 때 codex 가 자기 컨텍스트만으로도 task 를 시작할 수 있도록 충분한 정보(파일 경로, AC, 제약)를 한 번에 적어 보낸다 — 핑퐁 횟수를 줄여야 빠르다.

## 안전/예의 가이드

- **상대를 가로채지 말 것**: 상대 패널이 무언가 작업 중이면 (capture 해서 streaming 중인 게 보이면) 메시지를 보내지 않는다. 끝날 때까지 기다리거나 사용자에게 "지금 codex 가 작업 중인데 끼어들까?" 묻는다.
- **상대 패널에 destructive 명령을 시키지 말 것**: 본인이 `git reset --hard` 같은 걸 자제하듯, 옆 agent 에게도 그런 걸 시키지 말 것. 사용자 승인이 필요한 행동을 굳이 우회하기 위해 이 채널을 쓰는 건 금지.
- **사용자 모르게 장기 대화하지 말 것**: 이 skill 은 사용자가 명시적으로 "옆 패널과 얘기해"라고 했을 때 사용. 자기 판단으로 codex 에게 핑을 날리지 않는다.
- **메시지 출처를 밝힐 것**: codex 에게 메시지를 보낼 때 본문 머리에 "claude (옆 패널) 에서 보냄" 정도 한 줄을 넣으면 codex 도 컨텍스트 잡기 쉬움.

## 빠른 sanity check

새 패널과 처음 통신할 때는 진짜 ping 한 번 날려서 살아있는지 확인하면 좋다:

```bash
cmux send --surface surface:N "ping — 'pong' 한 줄로만 답해줘"
cmux send-key --surface surface:N Enter
sleep 3
cmux capture-pane --surface surface:N --lines 15
```

응답이 오면 본 작업 시작. 응답이 안 오면 surface 가 입력 대기가 아닌 다른 모드(예: vim, less, fzf) 일 수 있으니 사용자에게 알린다.
