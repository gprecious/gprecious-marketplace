# DevSweep — Full Disk Access 온보딩 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 비샌드박스 Developer ID 앱 DevSweep이 Full Disk Access(FDA) 권한 부재를 감지하고, 팝오버 ⚠ 배너 + 메뉴바 경고 tint + 첫 실행 1회 자동 팝오버로 안내한 뒤, 권한 부여 시 자동 재스캔으로 정상화하는 온보딩 레이어를 얹는다.

**Architecture:** 기존 코드 스타일(주입 가능한 IO + 순수 decider + `@Published` 상태 + AppKit status item 푸시)을 그대로 따른다. **테스트 타깃이 `DevSweepCoreTests`(→ `DevSweepCore`) 하나뿐이고 `DevSweepApp`은 테스트 불가 실행 타깃**이므로, FDA *로직*(probe·decider·launcher·presentation)은 전부 `DevSweepCore`에 두어 단위 테스트하고, `AppCoordinator`/`MenuView`/`StatusItemController`의 AppKit·SwiftUI 배선은 얇은 컴파일-검증 글루로만 둔다. 이는 `SkinSelectionReconciler`가 `AppCoordinator`에서 순수 로직을 떼어내 테스트한 선례와 동일하다.

**Tech Stack:** Swift 6 / SwiftPM / Swift Testing (`@Test`/`@Suite`/`#expect`), AppKit, SwiftUI, POSIX `open()`/`close()`, `NSWorkspace`.

---

## 설계 결정 / spec 대비 의도적 편차 (회귀 가드 + 리뷰어 주의)

이 세 가지는 spec(§3~§4)을 글자 그대로가 아니라 **의미 기준으로 reconcile**한 결과다. 모두 테스트 가능성·UX 때문이며, orchestrator 검증 시 인지 필요:

1. **`SettingsLauncher`를 `DevSweepCore`에 배치** (spec §3.3은 `DevSweepApp`이라 적음). 이유: `DevSweepApp`엔 테스트 타깃이 없어 spec §7의 "SettingsLauncher stub 호출 검증"이 불가능. `DevSweepCore`는 이미 `StatusItemPresentation`에서 AppKit을 import하므로 `NSWorkspace` 기반 실제 구현을 두는 데 무리 없음. 딥링크 URL 상수가 테스트 가능해져 회귀 가드 가치가 생김.
2. **`AppCoordinatorFDATests` 대신 `FDAOnboardingDeciderTests`로 동치 검증.** `AppCoordinator`(DevSweepApp)는 테스트 타깃이 없으므로(코드 주석에 "no test target" 명시, `SkinSelectionReconciler` 선례), spec §7이 `AppCoordinatorFDATests`에 귀속시킨 행동(denied→granted 재스캔 **1회**, 자동팝오버 **1회**)을 순수 decider(`decide` + `shouldRescanOnTransition`)에 대한 테스트로 검증한다. `AppCoordinator.refreshFDA()`는 이 decider를 호출하는 얇은 글루.
3. **경고 tint = `.systemOrange`** (spec §4.3 예시는 `.systemRed`, "예:"로 표기된 illustrative 값). 이유: `.systemRed`는 이미 "high 디스크 압박" tint라 FDA 경고와 충돌. 주황이 "주의(권한)"과 "위험(디스크)"을 구분.

## 불변식 (spec §8 — 회귀 가드)

1. FDA 자동 요청 시도 금지 — 설정 딥링크가 유일 경로.
2. 자동 팝오버는 첫 실행 1회만 — `DevSweep.didAutoShowFDAOnboarding` flag로 강제, decider가 단일 게이트.
3. "나중에" = 영구 dismiss 아님 — 권한 없으면 다음 팝오버 오픈 시 배너 재등장.
4. probe 불확실 시 `.denied`로 fail-safe — `fd >= 0`만 granted, 그 외 모든 결과(EPERM/EACCES/ENOENT/…) denied.
5. granted 전환 시 자동 재스캔 — `previousHasAccess == false && newStatus == .granted`일 때만(1회).
6. 기존 호출부 무변경 — 새 의존성은 기본값 주입, `AppCoordinator()`/`MenuView(...)` 기존 호출 그대로 컴파일.

## File Structure

**신규 (DevSweepCore — 테스트 대상):**
- `Sources/DevSweepCore/App/FullDiskAccessProbe.swift` — `FDAStatus` enum, `FullDiskAccessProbe` protocol, `TCCDatabaseProbe`.
- `Sources/DevSweepCore/App/FDAOnboardingDecider.swift` — `FDAOnboardingDecision` struct, `FDAOnboardingDecider`(decide + shouldRescanOnTransition).
- `Sources/DevSweepCore/App/SettingsLauncher.swift` — `SettingsLauncher` protocol, `SystemSettingsLauncher`(NSWorkspace 딥링크 + 노출된 URL 상수).

**수정 (DevSweepCore):**
- `Sources/DevSweepCore/App/StatusItemPresentation.swift` — `style(...)`에 `hasFullDiskAccess` 파라미터 추가(경고 tint 우선).

**수정 (DevSweepApp — 컴파일 검증 글루, 단위 테스트 없음):**
- `Sources/DevSweepApp/AppCoordinator.swift` — probe 주입, `@Published hasFullDiskAccess`, 콜백, `refreshFDA()`, `start()` 통합.
- `Sources/DevSweepApp/MenuView.swift` — `fdaBanner` + `settingsLauncher`/`onDismiss` 주입.
- `Sources/DevSweepApp/StatusItemController.swift` — FDA 상태 구독·경고 tint·자동 팝오버·오픈 시 refresh·MenuView 주입.

**신규/수정 테스트 (DevSweepCoreTests):**
- `Tests/DevSweepCoreTests/FullDiskAccessProbeTests.swift` (신규)
- `Tests/DevSweepCoreTests/FDAOnboardingDeciderTests.swift` (신규)
- `Tests/DevSweepCoreTests/SettingsLauncherTests.swift` (신규)
- `Tests/DevSweepCoreTests/StatusItemPresentationTests.swift` (수정 — FDA 경고 tint 케이스 추가)

---

## Task 0: 기존 그라운드워크 베이스라인 커밋

working tree에 이미 미커밋 그라운드워크가 있다(`StatusItemPresentation` 순수 단위 추출 + `MenuView`/`StatusItemController` 스캔중 UI 폴리시). FDA 작업이 이 파일들을 건드리므로, 깨끗한 히스토리를 위해 먼저 별도 커밋으로 고정한다. **베이스라인이 green일 때만.**

**Files:**
- Commit: `Sources/DevSweepCore/App/StatusItemPresentation.swift`, `Tests/DevSweepCoreTests/StatusItemPresentationTests.swift`, `Sources/DevSweepApp/MenuView.swift`, `Sources/DevSweepApp/StatusItemController.swift`

- [ ] **Step 1: 베이스라인 green 확인**

Run: `cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep && swift build && swift test 2>&1 | tail -5`
Expected: build 성공 + `Test run with N tests ... 0 failures` (현재 241 tests green).

- [ ] **Step 2: 그라운드워크만 커밋 (명시적 pathspec)**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepCore/App/StatusItemPresentation.swift \
        Tests/DevSweepCoreTests/StatusItemPresentationTests.swift \
        Sources/DevSweepApp/MenuView.swift \
        Sources/DevSweepApp/StatusItemController.swift
git commit -m "refactor(devsweep): extract StatusItemPresentation pure unit + scan-state UI polish"
```

> `git add -A`/`git add .` 금지. `shared/session-journal/session_journal_core.py` 및 untracked `.claude-code-debugger/`·`docs/dreams/`·`research/`는 절대 스테이징하지 않는다.

---

## Task 1: FullDiskAccessProbe + TCCDatabaseProbe

TCC.db를 `open(O_RDONLY)` probe로 FDA 유무를 판정. `fd >= 0`만 granted, 그 외 모두 fail-safe denied(불변식 4).

**Files:**
- Create: `Sources/DevSweepCore/App/FullDiskAccessProbe.swift`
- Test: `Tests/DevSweepCoreTests/FullDiskAccessProbeTests.swift`

- [ ] **Step 1: 실패 테스트 작성**

`Tests/DevSweepCoreTests/FullDiskAccessProbeTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// `TCCDatabaseProbe`는 `open(O_RDONLY)` 결과만으로 FDA 유무를 판정한다.
/// fail-safe(불변식 4): `fd >= 0`만 granted, 그 외 모든 결과는 denied.
@Suite struct FullDiskAccessProbeTests {
    @Test func readablePathReportsGranted() throws {
        let dir = NSTemporaryDirectory() + "devsweep-fda-\(UUID().uuidString)"
        let file = dir + "/probe.txt"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(TCCDatabaseProbe(path: file).check() == .granted)
    }

    @Test func missingPathFailsSafeToDenied() {
        let bogus = "/nonexistent/\(UUID().uuidString)/TCC.db"
        #expect(TCCDatabaseProbe(path: bogus).check() == .denied)
    }

    @Test func defaultProbeReturnsAValueWithoutCrashing() {
        // 현 머신 권한 상태 의존 → 값 단정 없음, 크래시·행 없이 둘 중 하나 반환만 확인.
        let status = TCCDatabaseProbe().check()
        #expect(status == .granted || status == .denied)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter FullDiskAccessProbeTests 2>&1 | tail -20`
Expected: 컴파일 실패 — `cannot find 'TCCDatabaseProbe' in scope` / `cannot find type 'FDAStatus'`.

- [ ] **Step 3: 구현**

`Sources/DevSweepCore/App/FullDiskAccessProbe.swift`:

```swift
import Foundation

/// Full Disk Access 권한 유무. FDA는 자동 요청 API가 없으므로 granted/denied 2-상태만 의미가 있다.
public enum FDAStatus: Sendable, Equatable {
    case granted
    case denied
}

/// 주입 가능한 FDA probe. 단위 테스트는 고정 상태를 반환하는 stub을 쓴다.
public protocol FullDiskAccessProbe: Sendable {
    func check() -> FDAStatus
}

/// `~/Library/Application Support/com.apple.TCC/TCC.db`를 `open(O_RDONLY)` 시도해 FDA를 판정한다.
/// 파일 내용은 읽지 않는다(권한 체크용 fd만). `fd >= 0`이면 `close` 후 `.granted`; 그 외 *모든*
/// 결과(EPERM/EACCES/ENOENT/경로 변경 등)는 fail-safe `.denied`(무권한 방치 < 배너 한 번 더).
public struct TCCDatabaseProbe: FullDiskAccessProbe {
    private let path: String

    public init(path: String = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db") {
        self.path = path
    }

    public func check() -> FDAStatus {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return .denied }
        close(fd)
        return .granted
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter FullDiskAccessProbeTests 2>&1 | tail -10`
Expected: 3 tests PASS, 0 failures.

- [ ] **Step 5: 커밋**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepCore/App/FullDiskAccessProbe.swift Tests/DevSweepCoreTests/FullDiskAccessProbeTests.swift
git commit -m "feat(devsweep): add FullDiskAccessProbe + TCC.db open-probe (fail-safe denied)"
```

---

## Task 2: FDAOnboardingDecider (순수 decider)

`SkinSelectionReconciler`와 동일한 순수-함수 패턴. 부수효과 없음 → 100% 단위 테스트. spec §7의 매트릭스 + "자동 팝오버 1회" + "denied→granted 재스캔 1회"를 모두 여기서 검증.

**Files:**
- Create: `Sources/DevSweepCore/App/FDAOnboardingDecider.swift`
- Test: `Tests/DevSweepCoreTests/FDAOnboardingDeciderTests.swift`

- [ ] **Step 1: 실패 테스트 작성**

`Tests/DevSweepCoreTests/FDAOnboardingDeciderTests.swift`:

```swift
import Testing
@testable import DevSweepCore

/// 순수 FDA 온보딩 decider — `AppCoordinator`(테스트 타깃 없음)의 FDA 행동을 여기서 검증한다
/// (`SkinSelectionReconciler` 선례). spec §7의 `AppCoordinatorFDATests` 의도를 동치로 커버:
/// - granted → 모든 신호 false
/// - denied & !didAutoShowBefore → 배너·경고·자동팝오버 모두 true
/// - denied & didAutoShowBefore → 자동팝오버만 false (배너·경고 유지) ← "자동 팝오버 1회" 불변식
/// - shouldRescanOnTransition → denied(false)→granted일 때만 true ← "재스캔 1회" 불변식
@Suite struct FDAOnboardingDeciderTests {
    private let decider = FDAOnboardingDecider()

    @Test func grantedShowsNothing() {
        for before in [false, true] {
            let d = decider.decide(status: .granted, didAutoShowBefore: before)
            #expect(d == FDAOnboardingDecision(showBanner: false, autoOpenPopover: false, warnIcon: false))
        }
    }

    @Test func deniedFirstRunShowsEverything() {
        let d = decider.decide(status: .denied, didAutoShowBefore: false)
        #expect(d == FDAOnboardingDecision(showBanner: true, autoOpenPopover: true, warnIcon: true))
    }

    @Test func deniedAfterAutoShowKeepsBannerButNotPopover() {
        let d = decider.decide(status: .denied, didAutoShowBefore: true)
        #expect(d.showBanner == true)
        #expect(d.warnIcon == true)
        #expect(d.autoOpenPopover == false) // 자동 팝오버는 첫 실행 1회만
    }

    @Test func rescanOnlyOnDeniedToGrantedTransition() {
        #expect(decider.shouldRescanOnTransition(previousHasAccess: false, newStatus: .granted) == true)
        // 전환 아님 → 재스캔 없음
        #expect(decider.shouldRescanOnTransition(previousHasAccess: nil, newStatus: .granted) == false)
        #expect(decider.shouldRescanOnTransition(previousHasAccess: true, newStatus: .granted) == false)
        #expect(decider.shouldRescanOnTransition(previousHasAccess: false, newStatus: .denied) == false)
        #expect(decider.shouldRescanOnTransition(previousHasAccess: true, newStatus: .denied) == false)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter FDAOnboardingDeciderTests 2>&1 | tail -20`
Expected: 컴파일 실패 — `cannot find 'FDAOnboardingDecider'` / `'FDAOnboardingDecision'`.

- [ ] **Step 3: 구현**

`Sources/DevSweepCore/App/FDAOnboardingDecider.swift`:

```swift
/// FDA 상태로부터 온보딩 표면 신호를 계산하는 순수 decision. 부수효과 없음.
public struct FDAOnboardingDecision: Sendable, Equatable {
    /// 팝오버 최상단 ⚠ 배너 표시.
    public let showBanner: Bool
    /// 팝오버 1회 자동 오픈(첫 실행 한정).
    public let autoOpenPopover: Bool
    /// 메뉴바 아이콘 경고 tint.
    public let warnIcon: Bool

    public init(showBanner: Bool, autoOpenPopover: Bool, warnIcon: Bool) {
        self.showBanner = showBanner
        self.autoOpenPopover = autoOpenPopover
        self.warnIcon = warnIcon
    }
}

/// 순수 FDA 온보딩 decider — `AppCoordinator`에서 떼어내 테스트 가능하게 한다
/// (`SkinSelectionReconciler`와 동일 패턴; 코디네이터는 테스트 타깃이 없음).
public struct FDAOnboardingDecider: Sendable {
    public init() {}

    /// granted → 모두 false. denied → 배너·경고 항상, 자동팝오버는 첫 실행(`!didAutoShowBefore`)만.
    /// `didAutoShowBefore`가 단일 게이트 — 호출부는 이중 체크하지 않는다.
    public func decide(status: FDAStatus, didAutoShowBefore: Bool) -> FDAOnboardingDecision {
        switch status {
        case .granted:
            return FDAOnboardingDecision(showBanner: false, autoOpenPopover: false, warnIcon: false)
        case .denied:
            return FDAOnboardingDecision(showBanner: true, autoOpenPopover: !didAutoShowBefore, warnIcon: true)
        }
    }

    /// denied(`previousHasAccess == false`)에서 granted로 *전환*될 때만 재스캔(1회). 최초 관측
    /// (`previousHasAccess == nil`)은 `start()`의 초기 스캔이 담당하므로 여기서 재스캔하지 않는다.
    public func shouldRescanOnTransition(previousHasAccess: Bool?, newStatus: FDAStatus) -> Bool {
        previousHasAccess == false && newStatus == .granted
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter FDAOnboardingDeciderTests 2>&1 | tail -10`
Expected: 4 tests PASS, 0 failures.

- [ ] **Step 5: 커밋**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepCore/App/FDAOnboardingDecider.swift Tests/DevSweepCoreTests/FDAOnboardingDeciderTests.swift
git commit -m "feat(devsweep): add FDAOnboardingDecider (banner/auto-popover/warn + rescan-once)"
```

---

## Task 3: SettingsLauncher + 딥링크 URL

FDA 설정 패널 딥링크를 연다. 주입 가능 → 테스트는 호출 기록 stub. 실제 URL 상수는 회귀 가드로 단정.

**Files:**
- Create: `Sources/DevSweepCore/App/SettingsLauncher.swift`
- Test: `Tests/DevSweepCoreTests/SettingsLauncherTests.swift`

- [ ] **Step 1: 실패 테스트 작성**

`Tests/DevSweepCoreTests/SettingsLauncherTests.swift`:

```swift
import Foundation
import Testing
@testable import DevSweepCore

/// 주입 가능한 stub은 호출 횟수를 기록한다(배너 "설정 열기" 경로가 정확히 1회 호출됨을 검증하는 데 사용).
private final class RecordingSettingsLauncher: SettingsLauncher, @unchecked Sendable {
    private(set) var callCount = 0
    func openFullDiskAccessSettings() { callCount += 1 }
}

@Suite struct SettingsLauncherTests {
    @Test func systemLauncherTargetsFullDiskAccessDeepLink() {
        #expect(
            SystemSettingsLauncher.fullDiskAccessSettingsURL.absoluteString
                == "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        )
    }

    @Test func recordingStubCountsCalls() {
        let launcher = RecordingSettingsLauncher()
        #expect(launcher.callCount == 0)
        launcher.openFullDiskAccessSettings()
        #expect(launcher.callCount == 1)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter SettingsLauncherTests 2>&1 | tail -20`
Expected: 컴파일 실패 — `cannot find type 'SettingsLauncher'` / `'SystemSettingsLauncher'`.

- [ ] **Step 3: 구현**

`Sources/DevSweepCore/App/SettingsLauncher.swift`:

```swift
import AppKit

/// FDA 설정 패널 딥링크를 여는 IO 추상화. 주입 가능 → 테스트는 호출 기록 stub.
/// (spec §3.3은 DevSweepApp이라 적었으나, 테스트 타깃이 없어 DevSweepCore로 이동 — `FullDiskAccessProbe`와
/// 동일하게 "시스템 접근" IO를 Core에 모은다.)
public protocol SettingsLauncher: Sendable {
    func openFullDiskAccessSettings()
}

/// `NSWorkspace`로 시스템 설정의 Full Disk Access 패널을 연다. 열기 실패 시 조용히 무시.
public struct SystemSettingsLauncher: SettingsLauncher {
    /// 시스템 설정 > 개인정보 보호 및 보안 > 전체 디스크 접근 권한 딥링크.
    public static let fullDiskAccessSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )!

    public init() {}

    public func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(Self.fullDiskAccessSettingsURL)
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter SettingsLauncherTests 2>&1 | tail -10`
Expected: 2 tests PASS, 0 failures.

- [ ] **Step 5: 커밋**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepCore/App/SettingsLauncher.swift Tests/DevSweepCoreTests/SettingsLauncherTests.swift
git commit -m "feat(devsweep): add SettingsLauncher + FDA settings deep-link"
```

---

## Task 4: StatusItemPresentation 경고 tint 합성

기존 `style(forBytes:low:high:)`에 `hasFullDiskAccess` 파라미터(기본 `true`)를 추가해 FDA 경고 tint를 게이지 tint보다 우선시킨다. 기본값으로 기존 2개 테스트·기존 render 호출 무변경.

**Files:**
- Modify: `Sources/DevSweepCore/App/StatusItemPresentation.swift`
- Test: `Tests/DevSweepCoreTests/StatusItemPresentationTests.swift` (케이스 추가)

- [ ] **Step 1: 실패 테스트 추가**

`Tests/DevSweepCoreTests/StatusItemPresentationTests.swift` 끝(파일 마지막 `}` 뒤, 최상위)에 추가:

```swift
@Test func statusItemPresentationUsesWarnTintWhenFullDiskAccessMissing() {
    let style = StatusItemPresentation.style(forBytes: 0, low: 5, high: 20, hasFullDiskAccess: false)
    #expect(style.imageTint.isEqual(NSColor.systemOrange))
    #expect(style.titleColor.isEqual(NSColor.labelColor)) // 제목은 여전히 가독 색
}

@Test func statusItemPresentationWarnTintOverridesHighPressureRed() {
    // FDA 경고가 게이지(high=red)보다 우선.
    let style = StatusItemPresentation.style(forBytes: 999, low: 5, high: 20, hasFullDiskAccess: false)
    #expect(style.imageTint.isEqual(NSColor.systemOrange))
    #expect(style.imageTint.isEqual(NSColor.systemRed) == false)
}

@Test func statusItemPresentationGrantedAccessKeepsGaugeTint() {
    let style = StatusItemPresentation.style(forBytes: 0, low: 5, high: 20, hasFullDiskAccess: true)
    #expect(style.imageTint.isEqual(NSColor.secondaryLabelColor)) // 기존 동작 보존
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter StatusItemPresentationTests 2>&1 | tail -20`
Expected: 컴파일 실패 — `extra argument 'hasFullDiskAccess' in call`.

- [ ] **Step 3: 구현**

`Sources/DevSweepCore/App/StatusItemPresentation.swift`의 `style(forBytes:low:high:)`를 다음으로 교체:

```swift
    public static func style(forBytes bytes: Int64, low: Int64, high: Int64, hasFullDiskAccess: Bool = true) -> Style {
        Style(
            imageTint: hasFullDiskAccess
                ? imageTint(forBytes: bytes, low: low, high: high)
                : .systemOrange, // FDA 경고가 게이지 tint보다 우선
            titleColor: .labelColor,
            titleFont: bytes >= high
                ? .boldSystemFont(ofSize: NSFont.systemFontSize)
                : .systemFont(ofSize: NSFont.systemFontSize)
        )
    }
```

- [ ] **Step 4: 통과 확인**

Run: `swift test --filter StatusItemPresentationTests 2>&1 | tail -10`
Expected: 기존 4 + 신규 3 = 7 tests PASS, 0 failures.

- [ ] **Step 5: 커밋**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepCore/App/StatusItemPresentation.swift Tests/DevSweepCoreTests/StatusItemPresentationTests.swift
git commit -m "feat(devsweep): StatusItemPresentation warn tint when FDA missing (overrides gauge)"
```

---

## Task 5: AppCoordinator FDA 배선 (컴파일 검증)

probe 주입(기본값)·`@Published hasFullDiskAccess`·콜백·`refreshFDA()`·`start()` 통합. DevSweepApp이라 단위 테스트 없음 — 로직은 Task 2 decider가 검증함. `swift build` green으로 검증.

**Files:**
- Modify: `Sources/DevSweepApp/AppCoordinator.swift`

- [ ] **Step 1: 저장 프로퍼티 + 발행 상태 + 콜백 추가**

`AppCoordinator.swift`에서 `@Published private(set) var isReclaiming = false` 다음 줄에 추가:

```swift

    /// FDA 권한 유무. SwiftUI(`MenuView` 배너)가 직접 관찰; status item은 `onFDAStateChange`로 푸시.
    /// 최초 probe 전엔 낙관적 `true`(권한 있는 사용자에게 경고 플래시 방지) — `start()`의 `refreshFDA()`가 즉시 보정.
    @Published private(set) var hasFullDiskAccess: Bool = true
```

그리고 `var onSkinChange: ((String) -> Void)?` 다음에 추가:

```swift

    /// FDA 상태가 갱신될 때 발화(메뉴바 아이콘 경고 tint 토글). status item이 구독.
    var onFDAStateChange: ((Bool) -> Void)?

    /// 첫 실행 1회 자동 팝오버 요청. status item이 구독해 프로그램적으로 팝오버를 연다.
    var requestAutoOpenPopover: (() -> Void)?
```

그리고 `private let skinReconciler = SkinSelectionReconciler()` 근처(저장 프로퍼티 영역)에 추가:

```swift

    /// 주입 가능한 FDA probe(기본 실제 구현) + 순수 decider + 직전 권한 상태(전환 감지용).
    private let fdaProbe: FullDiskAccessProbe
    private let fdaDecider = FDAOnboardingDecider()
    private var previousHasAccess: Bool?

    /// 자동 팝오버 1회 게이팅 flag의 UserDefaults 키.
    private static let fdaDidAutoShowKey = "DevSweep.didAutoShowFDAOnboarding"
```

- [ ] **Step 2: init에 probe 주입(기본값) 추가**

`init(config: AppConfig = .default) {` 를 다음으로 교체:

```swift
    init(config: AppConfig = .default, fdaProbe: FullDiskAccessProbe = TCCDatabaseProbe()) {
        self.config = config
        self.fdaProbe = fdaProbe
```

(기존 `self.config = config` 한 줄을 위 3줄로 대체 — `self.skinStore = ...` 이하 본문은 그대로.)

- [ ] **Step 3: refreshFDA() 추가 + start() 통합**

`start()` 본문 첫 줄 `notifier.requestAuthorizationIfPossible()` 다음에 추가:

```swift
        refreshFDA()
```

그리고 `start()` 끝의 `Task { await self.scanNow() }` 를 다음으로 교체(권한 있을 때만 초기 스캔; spec §5):

```swift
        // 권한이 있을 때만 초기 스캔(denied면 0 반환이라 강행 안 함). 이후 granted 전환은 refreshFDA가 재스캔.
        if hasFullDiskAccess {
            Task { await self.scanNow() }
        }
```

`reclaim(...)` 메서드 정의 다음(또는 `apply(record:)` 앞)에 새 메서드 추가:

```swift
    /// probe로 FDA 상태를 최신화하고, decision을 발행/콜백으로 전파한다. denied→granted 전환을
    /// 감지하면 즉시 재스캔(1회). 자동 팝오버는 첫 실행에만(decider가 게이트); flag는 콜백 발화 *전에*
    /// 저장해, 팝오버 오픈이 유발하는 재진입 refreshFDA가 같은 자동 팝오버를 다시 띄우지 못하게 한다.
    func refreshFDA() {
        let status = fdaProbe.check()
        let granted = (status == .granted)
        let didAutoShowBefore = UserDefaults.standard.bool(forKey: Self.fdaDidAutoShowKey)
        let decision = fdaDecider.decide(status: status, didAutoShowBefore: didAutoShowBefore)
        let shouldRescan = fdaDecider.shouldRescanOnTransition(previousHasAccess: previousHasAccess, newStatus: status)

        previousHasAccess = granted
        hasFullDiskAccess = granted
        onFDAStateChange?(granted)

        if decision.autoOpenPopover {
            UserDefaults.standard.set(true, forKey: Self.fdaDidAutoShowKey)
            requestAutoOpenPopover?()
        }
        if shouldRescan {
            Task { await scanNow() }
        }
    }
```

- [ ] **Step 4: 빌드 확인**

Run: `swift build 2>&1 | tail -15`
Expected: 컴파일 성공(경고 없음). 기존 `AppCoordinator()` 호출(AppDelegate)은 기본값 주입으로 무변경.

- [ ] **Step 5: 커밋**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepApp/AppCoordinator.swift
git commit -m "feat(devsweep): AppCoordinator FDA refresh/state (probe-injected, rescan on grant)"
```

---

## Task 6: MenuView FDA 배너 (컴파일 검증)

권한 없을 때 팝오버 최상단 ⚠ 배너. `settingsLauncher`/`onDismiss` 기본값 주입으로 기존 호출 무변경.

**Files:**
- Modify: `Sources/DevSweepApp/MenuView.swift`

- [ ] **Step 1: 주입 프로퍼티 추가**

`@State private var dryRun = true` 다음에 추가:

```swift

    /// FDA 설정 딥링크 런처(기본 실제 구현) + "나중에" 팝오버 닫기 콜백(status item이 주입).
    var settingsLauncher: SettingsLauncher = SystemSettingsLauncher()
    var onDismiss: () -> Void = {}
```

- [ ] **Step 2: body에 배너 분기 추가**

`var body: some View {` 의 `VStack(alignment: .leading, spacing: 12) {` 바로 다음(첫 자식 `header` 앞)에 추가:

```swift
            if !coordinator.hasFullDiskAccess {
                fdaBanner
                Divider()
            }
```

- [ ] **Step 3: fdaBanner 뷰 추가**

`private var header: some View {` 정의 앞에 추가:

```swift
    /// 권한 없을 때만 노출되는 경고 배너 — ⚠ + 설명 + [설정 열기]/[나중에]. "나중에"는 영구 dismiss 아님
    /// (불변식 3): 권한 없으면 다음 팝오버 오픈 시 재등장.
    private var fdaBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("전체 디스크 접근 권한 필요")
                    .font(.callout)
                    .fontWeight(.semibold)
            }
            Text("권한이 없으면 디스크 스캔이 빈 결과를 반환합니다. 시스템 설정에서 DevSweep을 허용해 주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("설정 열기") { settingsLauncher.openFullDiskAccessSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("나중에") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
```

- [ ] **Step 4: 빌드 확인**

Run: `swift build 2>&1 | tail -15`
Expected: 컴파일 성공.

- [ ] **Step 5: 커밋**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepApp/MenuView.swift
git commit -m "feat(devsweep): MenuView FDA warning banner (open settings / later)"
```

---

## Task 7: StatusItemController FDA 배선 (컴파일 검증)

FDA 상태 구독 → 경고 tint, 자동 팝오버 구독, 사용자 오픈 시 `refreshFDA()`, MenuView에 launcher/dismiss 주입.

**Files:**
- Modify: `Sources/DevSweepApp/StatusItemController.swift`

- [ ] **Step 1: MenuView 주입 인자 추가**

`popover.contentViewController = NSHostingController(` 블록을 다음으로 교체:

```swift
        popover.contentViewController = NSHostingController(
            rootView: MenuView(
                coordinator: coordinator,
                skinStore: coordinator.skinStore,
                settingsLauncher: SystemSettingsLauncher(),
                onDismiss: { [weak self] in self?.popover.performClose(nil) }
            )
        )
```

- [ ] **Step 2: FDA 콜백 구독 추가**

`coordinator.onSkinChange = { ... }` 클로저 블록 다음(init 끝의 `}` 앞)에 추가:

```swift
        // FDA 상태 변화 → 아이콘 경고 tint 재렌더(render가 coordinator.hasFullDiskAccess를 읽음).
        coordinator.onFDAStateChange = { [weak self] _ in
            guard let self else { return }
            self.render(bytes: self.coordinator.reclaimableBytes)
        }
        // 첫 실행 1회 자동 팝오버 — refresh를 다시 부르지 않는 show 경로(재진입 방지).
        coordinator.requestAutoOpenPopover = { [weak self] in
            self?.showPopover()
        }
```

- [ ] **Step 3: render에 hasFullDiskAccess 전달**

`render(bytes:)`의 `style` 계산을 다음으로 교체:

```swift
        let style = StatusItemPresentation.style(
            forBytes: bytes,
            low: coordinator.config.gaugeLowBytes,
            high: coordinator.config.gaugeHighBytes,
            hasFullDiskAccess: coordinator.hasFullDiskAccess
        )
```

- [ ] **Step 4: togglePopover에서 refresh + showPopover 분리**

`@objc private func togglePopover() { ... }` 전체를 다음으로 교체:

```swift
    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // 사용자가 열 때마다 권한 재확인 → granted 전환 시 배너 즉시 제거 + 재스캔(spec §4.3).
            coordinator.refreshFDA()
            showPopover()
        }
    }

    /// 팝오버를 연다(재진입 방지를 위해 refresh는 호출하지 않음 — 자동 팝오버 경로가 이 메서드를 직접 쓴다).
    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        let anchor = StatusItemPresentation.popoverAnchorRect(in: button.bounds)
        popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        keepPopoverInsideVisibleScreen(relativeTo: button)
    }
```

- [ ] **Step 5: 빌드 확인**

Run: `swift build 2>&1 | tail -15`
Expected: 컴파일 성공.

- [ ] **Step 6: 커밋**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
git add Sources/DevSweepApp/StatusItemController.swift
git commit -m "feat(devsweep): StatusItemController FDA warn tint + auto-popover + refresh on open"
```

---

## Task 8: 전체 그린 검증

**Files:** 없음(검증만).

- [ ] **Step 1: 전체 빌드 + 테스트**

Run: `cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep && swift build && swift test 2>&1 | tail -8`
Expected: build 성공 + 모든 테스트 green(241 기존 + 3+4+2+3=12 신규 = 253 tests), 0 failures.

- [ ] **Step 2: 불변식 스폿 체크 (코드 그렙)**

Run:
```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace/DevSweep
grep -n "fd >= 0" Sources/DevSweepCore/App/FullDiskAccessProbe.swift          # 불변식 4
grep -n "didAutoShowBefore" Sources/DevSweepCore/App/FDAOnboardingDecider.swift # 불변식 2
grep -n "Privacy_AllFiles" Sources/DevSweepCore/App/SettingsLauncher.swift     # 딥링크 유일 경로(불변식 1)
grep -n "previousHasAccess == false" Sources/DevSweepCore/App/FDAOnboardingDecider.swift # 불변식 5
```
Expected: 각 라인 매치.

- [ ] **Step 3: git 상태 확인 (push 금지)**

Run: `git -C /Users/taejin/Documents/dev/gprecious-marketplace log --oneline -12 && git -C /Users/taejin/Documents/dev/gprecious-marketplace status -sb`
Expected: Task 0~7 커밋이 보이고, 보호 대상(`session_journal_core.py`, untracked 디렉토리)은 여전히 미스테이징/untracked. **`git push` 하지 않는다.**

---

## Self-Review

**1. Spec coverage:**
- §3.1 FullDiskAccessProbe/TCCDatabaseProbe → Task 1 ✓
- §3.2 FDAOnboardingDecision/Decider → Task 2 ✓
- §3.3 SettingsLauncher → Task 3 ✓ (DevSweepCore로 이동, 편차 #1 문서화)
- §4.1 AppCoordinator(주입·@Published·콜백·refreshFDA·게이팅·재스캔·start 흐름) → Task 5 ✓
- §4.2 MenuView 배너 → Task 6 ✓
- §4.3 StatusItemController(경고 tint·자동 팝오버·오픈 시 refresh) → Task 4(tint 합성) + Task 7 ✓
- §5 데이터 흐름(start→refreshFDA, granted만 초기 스캔, 오픈 시 refresh) → Task 5/7 ✓
- §6 에러 처리(fail-safe denied, 딥링크 실패 무시, flag 실패 안전) → Task 1/3, refreshFDA flag는 best-effort ✓
- §7 테스트(Decider 매트릭스+1회 불변식, AppCoordinator 행동→Decider 동치, SettingsLauncher stub, TCCDatabaseProbe smoke) → Task 1~4 ✓ (편차 #2 문서화)
- §8 불변식 → 본문 "불변식" + Task 8 그렙 ✓

**2. Placeholder scan:** TODO/TBD/"add error handling" 등 없음 — 모든 코드 step에 실제 코드 포함. ✓

**3. Type consistency:** `FDAStatus`(.granted/.denied), `FullDiskAccessProbe.check()`, `FDAOnboardingDecision(showBanner:autoOpenPopover:warnIcon:)`, `FDAOnboardingDecider.decide(status:didAutoShowBefore:)`/`shouldRescanOnTransition(previousHasAccess:newStatus:)`, `SettingsLauncher.openFullDiskAccessSettings()`, `SystemSettingsLauncher.fullDiskAccessSettingsURL`, `StatusItemPresentation.style(forBytes:low:high:hasFullDiskAccess:)`, `AppCoordinator.hasFullDiskAccess`/`onFDAStateChange`/`requestAutoOpenPopover`/`refreshFDA()`, `MenuView.settingsLauncher`/`onDismiss`/`fdaBanner`, `StatusItemController.showPopover()` — 태스크 간 명칭/시그니처 일치. ✓
