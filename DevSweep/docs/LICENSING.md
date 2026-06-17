# DevSweep Pro — LemonSqueezy 라이선스 셋업

DevSweep Pro 는 LemonSqueezy 라이선스 키로 잠금해제된다(StoreKit 아님 — Developer ID 배포라 불가).
License API(`/v1/licenses/activate|validate|deactivate`)는 **API 키가 필요 없다** — 라이선스 키
자체가 인증 파라미터다. 앱이 직접 호출하고 별도 백엔드/영수증 서버가 없다. client-side 검증은
우회 가능하며, 이는 의도된 "캐주얼 라이선싱"이다(과한 anti-piracy 미적용).

## 대시보드에서 한 번 할 일 (자동화 불가)
1. LemonSqueezy 스토어 생성.
2. 상품 "DevSweep Pro": 평생 1회 **$9.99 출시가**, **License keys 활성화**, `activation limit = 3`.
3. 다음 값을 `Sources/DevSweepCore/License/LicenseConfig.swift` 의 `.production` 에 기입(전부 공개값):
   `checkoutURL`(buy URL), `expectedStoreId`(정수), `expectedProductIds`(product id 정수), `displayPrice`.
4. 테스트 모드 라이선스 키로 통합 검증.

## 검증 (테스트 모드 키)
- activate → "DevSweep Pro 활성화됨" + 스킨/전체회수/자동청소 토글 해제 확인.
- 환불/disable 시뮬 후 validate → 즉시 free 복귀(grace 무시) 확인.
- "이 기기에서 라이선스 해제" → 좌석 반납 + free + 선택중이던 유료 스킨 즉시 기본값 복귀 확인.
- 네트워크 차단 후 재실행 → 14일 grace 내 Pro 유지 확인.
- 자동 청소 ON: node_modules·worktree 는 **자동 삭제되지 않고** 캐시류만 회수되는지 확인.

## 출시 전 하드 게이트 (rev #11)
- `LicenseConfig.production` placeholder 교체 + 위 테스트모드 activate→Pro→deactivate→grace 1회
  실측 통과 전에는 `build_app.sh --dmg`/notarized 빌드가 차단된다.
