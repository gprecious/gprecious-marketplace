# Figma integration

design pane 만 Figma MCP 가 필요 (다른 페인은 불필요).

## A 단계 (plan 후)

design pane 부트스트랩 시 plan 의 figma_frame_urls 를 같이 주입. design pane 이 MCP 로 fetch.

## B 단계 (dev 후) — 일치도 검증

orchestrator 가 다음 흐름 수행:

```
1. 05-dev.md 에서 변경된 페이지/컴포넌트 경로 추출
2. manifest.visualization_command 로 dev 서버 또는 storybook 시작
   (사용자가 워크플로우 시작 시 명시. 비어있으면 critical)
3. Playwright 로 자동 스크린샷:
   .cmux-orchestrator/<slug>/screenshots/<component>-actual.png
4. design pane (B 단계) 에 메시지 전송:
   "B 단계 검증. 02-design.md 의 figma_frame_urls vs <screenshot 경로> 비교, 07-design-verify.md 작성"
5. design pane 이 정성 평가표 작성 (spacing / color / component variant / layout)
6. match_status ∈ {pass, partial, fail}
```

## 후속 처리

- pass → review 단계
- partial → fix_hint 묶어서 dev 재투입, 재검증 (1 retry)
- fail 또는 retry 후 partial 잔여 → critical

## Figma 없는 경우

plan 의 figma_frame_urls 가 비어있으면 design 단계 자체를 skip (workflow 분류가 `new-feature-no-ui` 등). orchestrator 는 이 상태를 정상으로 인식.

## visualization_command 자동 감지

manifest 의 `visualization_command` 가 null 이면 orchestrator 가 `package.json` scripts 를 보고 디폴트 추천:

- `storybook` 스크립트 있음 → `pnpm storybook` (포트 6006)
- `dev` 또는 `dev-app` 스크립트 → 그대로
- 없음 → critical, 사용자에게 명령 묻기

## Playwright 의존

orchestrator 가 cwd 에서 `npx playwright --version` 으로 설치 확인. 없으면 critical, 사용자에게 설치 요청 또는 visual verify skip 동의 묻기.
