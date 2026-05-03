# Model routing

## 기본 매핑

| 역할          | 기본 모델 | 근거                               |
| ------------- | --------- | ---------------------------------- |
| plan          | claude    | 아키텍처/추론 우위 (벤치마크 기반) |
| design        | claude    | Figma MCP 호환성                   |
| test-scenario | claude    | 명제 분해 정확도                   |
| test-code     | codex     | 구현 grinding 우위                 |
| dev           | codex     | 구현 grinding 우위                 |
| review        | claude    | 코드 리뷰 / 추론 우위              |

## Override 휴리스틱

기본 매핑은 휴리스틱이고 task 성격에 따라 orchestrator 가 조정 가능:

- **복잡한 동시성/디버깅 dev** → claude 로 교체 검토
- **단순 CRUD dev** → codex (기본값 유지, 빠름)
- **고품질 review 필요 (보안/돈 흐름)** → review 에 dual pane (claude + codex 동시) 검토
  - dual pane 발동은 critical → 사용자 한 줄 보고 ("review 에 듀얼 모델 띄움 — 토큰 2배")
- **codex 가 figma MCP 미지원** (2026-04 시점 미검증) → design 은 항상 claude 고정

override 결정은 critical 보고 대상 (사용자가 "왜 codex 대신 claude 썼지" 알아야 함).

## CLI 호출

```bash
# claude pane
claude --dangerously-skip-permissions

# codex pane
codex --dangerously-bypass-approvals-and-sandbox
```

`--dangerously-*` 플래그는 사용자가 cmux 환경 자체를 sandbox 로 보고 동의한 것 — 본 skill 의 모든 페인은 이 옵션으로 spawn (사용자 권한 prompt 차단).
