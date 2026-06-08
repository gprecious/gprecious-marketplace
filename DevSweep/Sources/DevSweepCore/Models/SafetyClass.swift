/// How dangerous it is to reclaim a candidate.
public enum SafetyClass: Sendable, Equatable {
    /// Pure cache the owning tool regenerates. May be auto-cleaned only when the
    /// user has explicitly opted that category into automatic cleanup.
    case autoSafe
    /// Reclaimable but has a re-cost (e.g. node_modules). Always requires explicit approval.
    case reviewNeeded
    /// Never touched. Not even shown as a candidate.
    case protected
}
