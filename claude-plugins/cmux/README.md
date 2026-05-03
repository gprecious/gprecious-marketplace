# cmux plugin

cmux 멀티페인 터미널 위에서 Claude Code 와 Codex 세션을 역할별 페인으로 자동 오케스트레이션하는 skill 묶음.

## 포함 skill

### `cmux-pane-chat`

cmux 워크스페이스 안의 다른 터미널 패널(codex, 다른 claude 세션, 일반 shell)에 메시지를 보내고 응답을 읽기 위한 표준 워크플로우.

- 트리거: "옆 패널", "다른 패널", "codex 에게"
- 핵심 명령 4종 (`cmux pane list/send/capture` 등) 표준화
- 사전 점검 (`CMUX_SOCKET_PATH`, `which cmux`) 가이드 포함

### `cmux-orchestrator`

여러 페인(plan / design / test-scenario / test-code / dev / review)에 역할을 분배하고 한 피처를 끝까지 처리하는 풀 파이프라인.

- 트리거: "여러 페인 띄워서", "멀티 에이전트로", "오케스트레이션", "claude 와 codex 같이", "plan-dev-review 분리"
- Figma 디자인 일치도 검증, RED 테스트 → GREEN 구현, AC 기반 단계별 검증 포함
- `commands/cmux-orchestrate.md` 슬래시 커맨드 제공
- `scripts/` (manifest, send-and-poll, pane-status, compact-or-fork, install-hooks) + `tests/` (bats) 동봉

## 설치

```bash
# Claude Code에서
/plugin add cmux@gprecious-marketplace
```

## 요구 사항

- macOS + cmux 앱 설치 (`/Applications/cmux.app`)
- `CMUX_SOCKET_PATH` 환경 변수 (cmux 워크스페이스에서 자동 설정)
- 페인에서 사용할 CLI: `claude`, `codex` (선택)

## 사용 예

```
사용자: 이 피처를 plan/dev/review 패널 나눠서 만들어줘
→ cmux-orchestrator 발동, 페인 자동 배치 + TDD 사이클 진행

사용자: 옆 codex 패널에 이 코드 리뷰 부탁해줘
→ cmux-pane-chat 발동, 메시지 송신 + 응답 capture
```
