# DevSweep Milestone 5 — SkinRenderer / 인디케이터 Implementation Plan

> **For agentic workers:** TDD for pure logic + 렌더 결정성. M1~M4 컨벤션. 작업 디렉토리 `DevSweep/`. push 금지.

**Goal:** 회수 가능 용량을 메뉴바에 "스킨"으로 시각화. 회수량→비주얼 상태 매핑(순수) + 스킨별 NSImage 렌더러 + 내장 스킨 N종 + StatusItem 연동 + 스킨 선택. RunCat식 수익화(M6)의 판매 대상(스킨)을 여기서 만든다.

**Architecture:** `ReclaimVisualState`(순수: bytes→band/fillRatio/critical) + `SkinModule` 프로토콜(id/displayName/isFree/`image(for:height:)`) + 내장 스킨(절차적 드로잉, 에셋 불요) + `SkinRenderer`(현재 스킨 보관·렌더) + StatusItemController가 텍스트 대신(또는 병행) 스킨 이미지 표시 + MenuView 스킨 선택(무료/잠금). 무료=모노크롬 template(라이트/다크 자동), 유료=컬러 가능(M6에서 잠금 해제).

**Tech Stack:** Swift 6.0 / AppKit(NSImage, NSBezierPath, Core Graphics) / Swift Testing. 외부 의존성 금지.

**Spec 근거:** `docs/superpowers/specs/2026-06-08-devsweep-design.md` §5(인디케이터: reclaimableBytes→시각, 5/20GB 임계, template 이미지, 불투명도 단계, 상태전이), §6(스킨 IAP 라인업).

**브랜치:** `design/devsweep-menubar-cleaner` (HEAD eced362, 124 tests green).

---

## File Structure (신규)
```
DevSweep/Sources/DevSweepCore/Skin/
├── ReclaimVisualState.swift   # 순수: bytes + config(low/high) → band(0/1/2)/fillRatio(0...1)/isCritical
├── SkinModule.swift           # 프로토콜 + SkinCatalog(내장 스킨 목록, free/paid 구분)
DevSweep/Sources/DevSweepApp/Skins/
├── SkinRenderer.swift         # 현재 스킨 보관, image(for:height:) 위임
├── GaugeSkin.swift            # 무료: 충전식 세로 게이지(fillRatio 채움 + critical 강조)
├── BatterySkin.swift          # 무료: 배터리 윤곽 + 충전 레벨 = fillRatio
├── DotMatrixSkin.swift        # 유료(컬러): band별 색 도트(회색/노랑/빨강), 픽셀풍
└── SynthwaveGaugeSkin.swift   # 유료(컬러): 네온 그라데이션 게이지
DevSweep/Tests/DevSweepCoreTests/
├── ReclaimVisualStateTests.swift
└── SkinRenderingTests.swift   # 각 스킨이 band별 정확 크기 NSImage 비-빈 렌더, 무료스킨 template 플래그, 결정성
```
> Skin 프로토콜/순수 매핑은 DevSweepCore(테스트 타깃 접근), 실제 드로잉 스킨은 DevSweepApp(AppKit). SkinModule 프로토콜은 `image(for:height:) -> NSImage` 라 AppKit 필요 → SkinModule.swift 도 `import AppKit` (Core는 이미 macholib AppKit 링크 가능; 안 되면 SkinModule 프로토콜을 DevSweepApp 으로 이동). **판단은 워커**: 순수 매핑(ReclaimVisualState)만 Core, NSImage 의존 전부 App 으로 둬도 됨.

## 타입 계약
```swift
// 순수 (Core)
public struct ReclaimVisualState: Sendable, Equatable {
    public let band: Int          // 0:<low, 1:low~high, 2:>=high
    public let fillRatio: Double   // min(bytes/high,1) 0...1
    public let isCritical: Bool    // band==2
    public init(reclaimableBytes: Int64, low: Int64, high: Int64)
}
// 스킨 (App, AppKit)
public protocol SkinModule: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isFree: Bool { get }
    /// height pt 기준 NSImage. 무료 스킨은 `image.isTemplate = true`(모노크롬). 유료는 컬러 허용.
    func image(for state: ReclaimVisualState, height: CGFloat) -> NSImage
}
```

## 렌더 검증 모드 (필수 — 시각 검증 수단)
`Sources/DevSweepApp/main.swift` 에 인자 모드 추가: `DevSweepApp --render-samples <outDir>` 이면 GUI 기동 대신, 모든 내장 스킨 × 대표 byte 레벨(0 / 2GB / 12GB / 30GB)을 PNG(@2x, 높이 18pt)로 `<outDir>/<skin>-<level>.png` 에 쓰고 즉시 종료(NSApplication.run 안 함). 이걸로 메뉴바 캡처 없이 스킨을 눈으로 확인.

## Tasks (TDD)
1. **ReclaimVisualState** (TDD: 0/2/12/30GB → band·fillRatio·critical 경계). 커밋 `feat(devsweep): ReclaimVisualState (회수량→비주얼 매핑)`.
2. **SkinModule 프로토콜 + SkinCatalog**. 커밋 `feat(devsweep): SkinModule protocol + catalog`.
3. **GaugeSkin + BatterySkin (무료, template)** + 렌더 테스트(band별 비-빈 NSImage, 정확 height, isTemplate=true, 동일 입력 결정성). 커밋 `feat(devsweep): free skins (gauge, battery)`.
4. **DotMatrixSkin + SynthwaveGaugeSkin (유료, 컬러)** + 테스트(컬러 픽셀 존재, isTemplate=false). 커밋 `feat(devsweep): paid skins (dot-matrix, synthwave)`.
5. **SkinRenderer + StatusItemController 연동**: 현재 스킨 이미지로 button.image 설정(+숫자 옵션 유지). AppCoordinator에 `currentSkinId` @Published + 변경 API. MenuView에 스킨 목록(무료 선택가능/유료 잠금 라벨). 커밋 `feat(devsweep): SkinRenderer + status item skin rendering + menu picker`.
6. **--render-samples 모드** (main.swift). 커밋 `feat(devsweep): --render-samples PNG export for skin verification`.
7. 게이트: `swift test` 전체 green + `swift build` 경고 0 + `swift run DevSweepApp --render-samples /tmp/devsweep-skins` 가 PNG 생성하고 즉시 종료(앱 안 띄움) 확인.

## 완료 신호
1. `M5_SKINS_DONE`
2. `swift test 2>&1 | tail -3`
3. `swift build 2>&1 | tail -1`
4. `swift run DevSweepApp --render-samples /tmp/devsweep-skins && ls /tmp/devsweep-skins` 결과
5. `git -C /Users/taejin/Documents/dev/gprecious-marketplace log --oneline -8`

## 비범위 (YAGNI)
- 커스텀 스킨 등록(UGC), 스킨 키프레임 PNG 임포트(RunCat 규격) — 후속.
- 실제 IAP 잠금 해제 로직 — M6.
- 애니메이션 프레임 타이머(상태전이) — 정적 렌더 우선, 애니메이션은 후속.
