# herdr plugin

[herdr](https://herdr.dev/) (terminal-native agent multiplexer) 위에서 Claude Code + Codex 워커를 병렬로 spawn / prompt 주입 / 완료 대기 / 결과 회수 / 자동 정리 하는 경량 orchestrator skill.

## 포함 skill

### `herdr-orchestrator`

worker N 개를 한 tab 당 최대 9 개 (3×3 grid), 9 개 초과 시 새 tab (`agents-2`, `agents-3`, …) 으로 spillover 하면서 spawn / prompt 주입 / 대기 / 회수 / 정리.

- 트리거: "herdr 로 claude+codex 같이", "두 에이전트 병렬", "여러 worker 병렬"
- 협업 패턴 (fan-out / split / 역할 분담) 은 호출자가 prompt 단계에서 결정 — skill 은 spawn·대기·회수·정리 primitive 만 제공.
- 새 workspace 격리 + send 직전 workspace_id 검증 + 실패 시 workspace 보존 (디버깅).
- default cleanup: 모든 worker 정상 종료 시 `herdr workspace close` 한 번으로 통째 정리.

## 설치

```bash
# Claude Code 에서
/plugin add herdr@gprecious-marketplace
```

## 요구 사항

- [herdr](https://herdr.dev/) 설치 + 실행 중 (`HERDR_ENV=1` 자동 설정).
- `claude` CLI (Claude Code) — OAuth/구독 로그인 완료.
- `codex` CLI — OAuth/구독 로그인 완료.
- (선택) 공식 `herdr` agent skill 활성화 — 워크스페이스/탭/페인 CLI 상세 사양 추가 참조.

## 인증 / 과금 정책 (불변)

본 plugin 의 모든 worker 호출은 OAuth/구독 CLI 만 사용:

- `claude --dangerously-skip-permissions`
- `codex --dangerously-bypass-approvals-and-sandbox`

`ANTHROPIC_API_KEY` / `OPENAI_API_KEY` 등 과금 API 키 사용 금지. SDK 직접 import / `api.anthropic.com` 직접 호출 금지.

## 사용 예

```
사용자: 이 함수 리팩토링 claude/codex 둘 다 시켜서 결과 비교해줘
→ herdr-orchestrator 발동
→ 새 workspace + agents-1 tab 안에 2 pane (claude / codex)
→ 동일 prompt fan-out → 병렬 대기 → 두 결과 회수
→ 호출자가 두 결과 비교 후 사용자에게 보고
→ workspace 자동 close

사용자: 이 PR 코드 리뷰를 6개 시각으로 동시에 받고 싶어 (claude x3 + codex x3)
→ herdr-orchestrator 발동
→ 새 workspace + agents-1 tab 안에 3x2 = 6 pane
→ 각 slot 별 시각 prompt → 병렬 대기 → 6 결과 회수
→ workspace 자동 close
```

## Claude Code / Codex 양쪽 호출

이 skill 은 호출자가 누구든 동일하게 동작 — 호출자 본인은 orchestrator 로 남고 worker pane 은 새 workspace 에 별도 spawn.

- **Claude Code 에서**: SKILL.md 자동 발동.
- **Codex 에서**: `claude-plugins/herdr/skills/herdr-orchestrator/SKILL.md` 를 prompt 에 명시 또는 직접 읽혀서 절차 수행.

자세한 내용은 [`skills/herdr-orchestrator/SKILL.md`](./skills/herdr-orchestrator/SKILL.md) 참고.
