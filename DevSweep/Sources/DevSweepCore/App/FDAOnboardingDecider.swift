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
