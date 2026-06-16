# herdr plugin

[herdr](https://herdr.dev/) (terminal-native agent multiplexer) 위에서 Claude Code + Codex 워커를 visible TUI pane 으로 병렬 실행해야 할 때 쓰는 orchestrator skill. 토큰 절감을 위해 subagent/lightweight delegation 을 먼저 검토하고, 새 herdr pane 은 visible TUI, 별도 CLI/account/browser state, 또는 명시적 pane fan-out 이 필요할 때만 만든다.

## 포함 skill

### `herdr-orchestrator`

필요하다고 판정된 worker N 개만 한 tab 당 최대 9 개 (3×3 grid), 9 개 초과 시 새 tab (`<slug>-2`, `<slug>-3`, …) 으로 spillover 하면서 spawn / prompt 주입 / 대기 / 회수 / 정리.

- 트리거: "herdr 로 claude+codex 같이", "herdr pane 새로", visible worker pane, cross-CLI 비교, worker 별 CLI/account/browser state 분리.
- "두 에이전트 병렬", "여러 worker 병렬", 리뷰 관점 fan-out 은 먼저 subagent/lightweight delegation 으로 처리할 수 있는지 본다.
- 협업 패턴 (fan-out / split / 역할 분담) 은 routing gate 통과 후 prompt 단계에서 결정 — skill 은 spawn·대기·회수·정리 primitive 를 제공.
- 호출자 workspace 공유 + worker 는 새 tab 에 격리 (`LAUNCHER_TAB` 은 안 건드림) + send 직전 worker-tab 검증 + 실패 시 worker tab 보존 (디버깅). 새 workspace 를 만들지 않아 workspace 가 누적되지 않는다.
- worker 의 **model·effort 를 난이도에 따라 orchestrator 가 자율 조정** — 최신 모델을 런타임에 확인한 뒤 선택. 단순 병렬 분석은 pane fan-out 대신 low/medium effort subagent 우선, 어려운 visible slot 은 **ultracode**로 1개 핵심 pane + 내부 subagent 를 먼저 고려.
- cleanup: 결과 보고 후 성공한 worker tab 은 자동 close, 실패 tab 만 디버깅용 보존 (workspace / `LAUNCHER_TAB` 보존).

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
사용자: herdr 로 이 함수 리팩토링을 claude/codex 둘 다 visible 하게 시켜서 결과 비교해줘
→ herdr-orchestrator 발동
→ 호출자 workspace 에 새 worker tab + 그 안에 2 pane (claude / codex)
→ 동일 prompt fan-out → 병렬 대기 → 두 결과 회수
→ 호출자가 두 결과 비교 후 사용자에게 보고
→ 성공한 worker tab 자동 close (workspace 유지)

사용자: 이 PR 코드 리뷰를 6개 시각으로 동시에 받고 싶어
→ herdr pane 이 꼭 필요한지 routing gate 확인
→ visible TUI / 별도 CLI state 가 없으면 subagent 6개 또는 더 작은 lightweight delegation 으로 처리
→ herdr pane 은 만들지 않음
```

## Claude Code / Codex 양쪽 호출

이 skill 은 호출자가 누구든 동일하게 동작 — 호출자 본인은 orchestrator 로 남고 routing gate 를 통과한 worker pane 만 호출자 workspace 안의 새 tab 에 별도 spawn.

- **Claude Code 에서**: SKILL.md 자동 발동.
- **Codex 에서**: `claude-plugins/herdr/skills/herdr-orchestrator/SKILL.md` 를 prompt 에 명시 또는 직접 읽혀서 절차 수행.

자세한 내용은 [`skills/herdr-orchestrator/SKILL.md`](./skills/herdr-orchestrator/SKILL.md) 참고.
