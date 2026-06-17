/// Pure rules for scheduled/automatic reclaim. Runs only when Pro + opted in, and may reclaim ONLY
/// `.autoSafe` candidates — `.reviewNeeded` items (node_modules, git-worktrees) require explicit
/// human approval per `SafetyClass`, so hands-off cleaning must never touch them (rev #1).
public struct AutoReclaimPolicy: Sendable {
    public init() {}
    public func shouldAutoReclaim(isPro: Bool, autoCleanEnabled: Bool) -> Bool { isPro && autoCleanEnabled }
    public func autoCleanableItems(from items: [CleanupItem]) -> [CleanupItem] {
        items.filter { $0.safety == .autoSafe }
    }
}
