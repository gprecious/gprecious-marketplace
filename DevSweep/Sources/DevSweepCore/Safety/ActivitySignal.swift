/// Gate ② building block: one heuristic that answers "does this path look in use right now?"
/// Implementations are injected so the Safety Layer is deterministic under test.
public protocol ActivitySignal: Sendable {
    /// Human-readable name, recorded in `SafetyEvaluation.downgradedBy`.
    var name: String { get }
    /// True if this signal considers `path` actively in use.
    func isActive(path: String) async -> Bool
}
