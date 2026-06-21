# 루프 카탈로그 (우리 맥락)

리서치의 Loop Library(FuelAI용 31개)를 그대로 쓰지 않고, QPLACE/gprecious 맥락으로 번역한
**검증 가능한 출발 템플릿**. 채택 여부·우선순위는 `/loop-design` triage와 사람 결정으로 정한다.

| 루프                    | trigger                           | verification(센서)                       | stop                   | backend           | human gate            |
| ----------------------- | --------------------------------- | ---------------------------------------- | ---------------------- | ----------------- | --------------------- |
| `preview-error-sweep`   | preview 배포 후 / 스케줄          | Chrome console·network 에러 0, smoke 200 | 에러 0 또는 issue 생성 | Cron / `/loop`    | 실제 수정 PR 전       |
| `migration-drift-check` | 스케줄 / 배포 전                  | beta PG 스키마 ↔ `src/migration/` diff   | drift 0 또는 리포트    | Codex Automations | drift 수동 적용 결정  |
| `docs-drift-sweep`      | 스케줄                            | CLAUDE.md/AGENTS.md ↔ 코드 일치          | 불일치 0 또는 리포트   | Cron              | 문서 수정 PR 전       |
| `e2e-healer`            | CI 실패 / vitest·Playwright trace | 테스트 재실행 GREEN                      | GREEN 또는 max-iter    | herdr / Workflow  | 구현 변경이 클 때     |
| `pr-review-loop`        | PR open                           | beomgu/api-cms 패턴·품질 리뷰어 통과     | 리뷰 통과              | Workflow          | merge 결정            |
| `lint-type-sweep`       | 스케줄                            | `pnpm lint` + `tsc` exit 0               | exit 0 또는 리포트     | Cron              | 없음(저위험 자동완료) |

각 레시피는 빈칸 없는 출발점이다. `/loop-design`은 사용자가 카탈로그 항목을 고르면 해당 행을
`loop-spec.md` 템플릿에 펼쳐 채운다.
