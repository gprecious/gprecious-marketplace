import Testing
@testable import DevSweepCore

/// dry-run preview is always free; per-module real reclaim is free for EVERY module (Docker opened
/// to free, rev product-decision); only the one-click "reclaim all" convenience is Pro.
@Suite struct ReclaimGateTests {
    private let gate = ReclaimGate()
    @Test func dryRunAlwaysAllowed() {
        #expect(gate.decide(scope: .all, isPro: false, dryRun: true) == .allow)
        #expect(gate.decide(scope: .module("docker"), isPro: false, dryRun: true) == .allow)
    }
    @Test func reclaimAllRequiresProWhenNotPro() {
        #expect(gate.decide(scope: .all, isPro: false, dryRun: false) == .requiresPro)
    }
    @Test func reclaimAllAllowedWhenPro() {
        #expect(gate.decide(scope: .all, isPro: true, dryRun: false) == .allow)
    }
    @Test func everyPerModuleRealReclaimIsFree() {
        for id in ["node-modules", "package-cache", "git-worktrees", "docker"] {
            #expect(gate.decide(scope: .module(id), isPro: false, dryRun: false) == .allow)
        }
    }
}
