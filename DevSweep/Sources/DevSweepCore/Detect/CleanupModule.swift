/// A self-contained cleanup domain: it discovers its own candidates and reclaims them.
/// `scan()` is read-only (never deletes). `reclaim()` performs (or plans, when dryRun)
/// the actual reclaim — path-based modules delegate to the M1 Reclaimer; CLI-based
/// modules invoke the tool's own prune command and measure before/after.
public protocol CleanupModule: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// False when the underlying tool is absent/unresponsive → the registry hides it.
    func isAvailable() async -> Bool

    /// Candidates with size + safety class only. Never deletes.
    func scan() async -> [CleanupItem]

    /// Reclaim `items`. When `dryRun`, produces a plan and performs no side effects.
    func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome]
}
