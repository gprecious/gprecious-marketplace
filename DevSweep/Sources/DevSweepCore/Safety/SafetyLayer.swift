/// The single gate every deletion passes through. `evaluate` runs gates in order:
///   ③ protected-registry (absolute deny) → ② active-check signals → ① keep classification.
/// `evaluate` NEVER deletes anything; it only decides whether a candidate is allowed.
public struct SafetyLayer: Sendable {
    private let signals: [any ActivitySignal]
    private let registry: ProtectedRegistry

    public init(signals: [any ActivitySignal], registry: ProtectedRegistry) {
        self.signals = signals
        self.registry = registry
    }

    public func evaluate(_ item: CleanupItem) async -> SafetyEvaluation {
        // Gate ③ — protected registry is absolute.
        if registry.isProtected(path: item.path) {
            var downgraded = item
            downgraded.safety = .protected
            return SafetyEvaluation(item: downgraded, downgradedBy: ["protected-registry"])
        }

        // Gate ② — active-check signals (only meaningful for path-bearing items).
        var fired: [String] = []
        if let path = item.path {
            for signal in signals where await signal.isActive(path: path) {
                fired.append(signal.name)
            }
        }
        if !fired.isEmpty {
            var downgraded = item
            downgraded.safety = .protected
            return SafetyEvaluation(item: downgraded, downgradedBy: fired)
        }

        // Gate ① — no downgrade; keep the detector's original classification.
        return SafetyEvaluation(item: item, downgradedBy: [])
    }
}
