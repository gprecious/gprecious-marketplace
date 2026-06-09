import Testing
@testable import DevSweepCore

/// Pure decision logic for reconciling the selected skin against current entitlements — extracted
/// from `AppCoordinator` so the tricky one-shot-pending + refund-revert + load-guard branches are
/// actually tested (the coordinator has no test target).
///
/// Invariants under test:
/// - a persisted paid skin is applied **only once it's owned**, and `pending` is consumed only then
///   (so a premature/empty entitlement read can't discard it — the M6 launch-race);
/// - a refunded paid skin reverts to default, but **only after** entitlements have loaded (so a
///   transient empty read before the first load can't wrongly revert an owned skin).
@Suite struct SkinSelectionReconcilerTests {
    private let reconciler = SkinSelectionReconciler()
    private let free: Set<String> = ["gauge", "battery"]

    @Test func freeSelectionWithNothingPendingIsUnchanged() {
        let d = reconciler.reconcile(
            currentSelection: "gauge", pendingSelection: nil,
            freeSkinIds: free, unlockedSkinIds: [], didLoadEntitlements: true, defaultSkinId: "gauge"
        )
        #expect(d.selection == "gauge")
        #expect(d.clearedPending == false)
    }

    @Test func pendingPaidSkinAppliedOnceOwned() {
        let d = reconciler.reconcile(
            currentSelection: "gauge", pendingSelection: "dot-matrix",
            freeSkinIds: free, unlockedSkinIds: ["dot-matrix"], didLoadEntitlements: true, defaultSkinId: "gauge"
        )
        #expect(d.selection == "dot-matrix")
        #expect(d.clearedPending == true)
    }

    @Test func pendingPaidSkinPreservedWhileNotYetLoaded() {
        // The launch-race: an early empty entitlement read must NOT consume pending.
        let d = reconciler.reconcile(
            currentSelection: "gauge", pendingSelection: "dot-matrix",
            freeSkinIds: free, unlockedSkinIds: [], didLoadEntitlements: false, defaultSkinId: "gauge"
        )
        #expect(d.selection == "gauge")
        #expect(d.clearedPending == false) // pending kept for the real load
    }

    @Test func pendingPaidSkinPreservedWhenLoadedButUnowned() {
        let d = reconciler.reconcile(
            currentSelection: "gauge", pendingSelection: "dot-matrix",
            freeSkinIds: free, unlockedSkinIds: [], didLoadEntitlements: true, defaultSkinId: "gauge"
        )
        #expect(d.selection == "gauge")
        #expect(d.clearedPending == false)
    }

    @Test func ownedSelectedPaidSkinIsKept() {
        let d = reconciler.reconcile(
            currentSelection: "synthwave", pendingSelection: nil,
            freeSkinIds: free, unlockedSkinIds: ["synthwave"], didLoadEntitlements: true, defaultSkinId: "gauge"
        )
        #expect(d.selection == "synthwave")
        #expect(d.clearedPending == false)
    }

    @Test func refundedPaidSkinRevertsToDefaultAfterLoad() {
        let d = reconciler.reconcile(
            currentSelection: "synthwave", pendingSelection: nil,
            freeSkinIds: free, unlockedSkinIds: [], didLoadEntitlements: true, defaultSkinId: "gauge"
        )
        #expect(d.selection == "gauge")
        #expect(d.clearedPending == false)
    }

    @Test func unownedPaidSkinNotRevertedBeforeFirstLoad() {
        // A transient empty read before entitlements load must not strip a selected paid skin.
        let d = reconciler.reconcile(
            currentSelection: "synthwave", pendingSelection: nil,
            freeSkinIds: free, unlockedSkinIds: [], didLoadEntitlements: false, defaultSkinId: "gauge"
        )
        #expect(d.selection == "synthwave")
        #expect(d.clearedPending == false)
    }

    @Test func pendingAppliedSkinIsNotThenReverted() {
        // Apply pending (owned) then the revert pass must see it as selectable and keep it.
        let d = reconciler.reconcile(
            currentSelection: "gauge", pendingSelection: "dot-matrix",
            freeSkinIds: free, unlockedSkinIds: ["dot-matrix"], didLoadEntitlements: true, defaultSkinId: "gauge"
        )
        #expect(d.selection == "dot-matrix")
        #expect(d.clearedPending == true)
    }
}
