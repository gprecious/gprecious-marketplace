/// Pure decision for reconciling the selected skin against current entitlements. Kept separate from
/// `AppCoordinator` (which has no test target) so the launch-race and refund branches are testable.
///
/// Two rules, in order:
/// 1. **Apply pending once owned** — a persisted *paid* skin can't be validated until entitlements
///    load, so it waits in `pendingSelection`. It's applied (and `pending` consumed) only when it's
///    actually selectable. An empty/early read leaves `pending` intact for the real load — without
///    this, a concurrent `Transaction.updates` tick could discard a legitimately-owned skin.
/// 2. **Revert if unowned, but only after load** — a refunded / family-sharing-lost paid skin reverts
///    to the default, gated on `didLoadEntitlements` so a transient empty read before the first load
///    can't strip a still-owned selection.
public struct SkinSelectionReconciler: Sendable {
    public struct Decision: Sendable, Equatable {
        /// The skin id to select (equals `currentSelection` when nothing changes).
        public let selection: String
        /// `true` when a pending selection was consumed (the caller should drop its `pending` id).
        public let clearedPending: Bool
    }

    public init() {}

    public func reconcile(
        currentSelection: String,
        pendingSelection: String?,
        freeSkinIds: Set<String>,
        unlockedSkinIds: Set<String>,
        didLoadEntitlements: Bool,
        defaultSkinId: String
    ) -> Decision {
        func selectable(_ id: String) -> Bool {
            freeSkinIds.contains(id) || unlockedSkinIds.contains(id)
        }

        var selection = currentSelection
        var clearedPending = false

        // 1. Apply a persisted paid skin once it's owned (one-shot — consume pending only on apply).
        if let pending = pendingSelection, selectable(pending) {
            selection = pending
            clearedPending = true
        }

        // 2. Revert a no-longer-owned paid skin, but only after entitlements have actually loaded.
        if didLoadEntitlements, !selectable(selection) {
            selection = defaultSkinId
        }

        return Decision(selection: selection, clearedPending: clearedPending)
    }
}
