# 레시피: _fallback (비웹 검증 방법론)

웹 UI E2E(Playwright)가 맞지 않는 프로젝트(CLI/라이브러리/API/배치 등)용. Playwright 를 쓰지 않는다.
`detect-stack.sh` 가 웹 프레임워크를 찾지 못하면(`recipe == "_fallback"`) 선택된다.
`constitution.md` 5원칙을 프로젝트의 기존 테스트 러너 위에 문서로 인코딩한다.

## 변수
| 변수 | 의미 |
|------|------|
| `testRunner` | 프로젝트의 테스트 러너 (예: pytest, jest, go test, cargo test). `detect-stack.sh` 가 감지하거나 사람이 지정. |
| `runCommand` | 테스트 실행 명령 (예: `pytest -q`). heal 루프가 호출한다. |

## 산출물
- `VERIFICATION-HARNESS.md` — 5원칙을 `{{testRunner}}`/`{{runCommand}}` 에 매핑한 방법론 문서.
- `critical-flows.md` — 크리티컬 플로우 워크시트(사람이 채운다).
- (러너가 식별되면) 해당 러너의 스텁 테스트 파일 — 스킬 실행 단계에서 사람과 함께 추가.

## 생성
```bash
bash skills/e2e-harness/lib/scaffold.sh --recipe _fallback \
  --target <project-dir> --var testRunner=pytest --var runCommand="pytest -q"
```

비웹이라 자동화된 그린 게이트 대신, 워크시트로 크리티컬 플로우를 합의하고 heal 루프로 러너를 돌린다.
