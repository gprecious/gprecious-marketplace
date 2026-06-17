# e2e-harness

대상 프로젝트 스택을 감지해 맞춤 E2E/검증 하네스를 대화형으로 생성하는 공용 스킬.
NAVER D2 "AI 에이전트를 위한 Playwright E2E 테스트 하네스" 원칙을 인코딩.

## 사용
스킬 `e2e-harness` 를 호출하면: 스택 감지 → 레시피 선택 → 크리티컬 플로우 Q&A →
하네스 생성 → 실행+heal. 레시피: nextjs-supabase / generic-web-playwright / _fallback(비웹).
