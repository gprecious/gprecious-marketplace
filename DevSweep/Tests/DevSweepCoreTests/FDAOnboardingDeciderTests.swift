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
