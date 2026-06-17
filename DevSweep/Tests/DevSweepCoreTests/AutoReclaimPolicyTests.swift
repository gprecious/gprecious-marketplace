import Testing
import Foundation
@testable import DevSweepCore

/// Auto-clean runs only when Pro AND opted in, and may ONLY reclaim `.autoSafe` items —
/// `.reviewNeeded` (node_modules / git-worktrees) always needs explicit approval (SafetyClass).
@Suite struct AutoReclaimPolicyTests {
    private let policy = AutoReclaimPolicy()
    private func item(_ id: String, _ safety: SafetyClass) -> CleanupItem {
        CleanupItem(id: id, path: "/x/\(id)", sizeBytes: 1, lastUsed: nil, safety: safety,
                    reclaimMethod: .deletePath(toTrash: true))
    }
    @Test func gatedOnProAndOptIn() {
        #expect(policy.shouldAutoReclaim(isPro: true, autoCleanEnabled: true))
        #expect(!policy.shouldAutoReclaim(isPro: true, autoCleanEnabled: false))
        #expect(!policy.shouldAutoReclaim(isPro: false, autoCleanEnabled: true))
    }
    @Test func selectsOnlyAutoSafeItems() {
        let items = [item("cache", .autoSafe), item("node_modules", .reviewNeeded), item("dockercache", .autoSafe)]
        let selected = policy.autoCleanableItems(from: items)
        #expect(Set(selected.map(\.id)) == ["cache", "dockercache"])   // reviewNeeded excluded (rev #1)
    }
}
