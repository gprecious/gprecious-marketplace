/// Pure free/Pro decision for reclaim actions. dry-run preview is always free; per-module real
/// reclaim is free for every module (Docker is free per product decision); only one-click
/// "reclaim all" is Pro (a convenience, not a capability gate).
public struct ReclaimGate: Sendable {
    public enum Scope: Sendable, Equatable { case all; case module(String) }
    public enum Decision: Sendable, Equatable { case allow, requiresPro }
    public init() {}
    public func decide(scope: Scope, isPro: Bool, dryRun: Bool) -> Decision {
        if dryRun || isPro { return .allow }
        switch scope {
        case .all: return .requiresPro
        case .module: return .allow
        }
    }
}
