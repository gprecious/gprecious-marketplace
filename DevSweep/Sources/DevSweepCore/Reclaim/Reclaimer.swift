/// Orchestrates reclaiming a set of candidates. Every item is re-evaluated through the
/// Safety Layer first. Dry-run produces a plan and never calls the deleter. Protected
/// items are skipped. CLI-based reclaim (docker prune etc.) lands in a later milestone.
public struct Reclaimer: Sendable {
    private let safety: SafetyLayer
    private let deleter: any FileSystemDeleter

    public init(safety: SafetyLayer, deleter: any FileSystemDeleter) {
        self.safety = safety
        self.deleter = deleter
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        var outcomes: [ReclaimOutcome] = []
        for item in items {
            let resolved = await safety.evaluate(item).item

            if resolved.safety == .protected {
                outcomes.append(ReclaimOutcome(item: resolved, status: .skippedProtected))
                continue
            }
            if dryRun {
                outcomes.append(ReclaimOutcome(item: resolved, status: .dryRun(plannedBytes: resolved.sizeBytes)))
                continue
            }

            switch resolved.reclaimMethod {
            case .deletePath(let toTrash):
                guard let path = resolved.path else {
                    outcomes.append(ReclaimOutcome(item: resolved, status: .failed(message: "deletePath item has no path")))
                    continue
                }
                do {
                    let bytes = try await deleter.delete(path: path, toTrash: toTrash)
                    outcomes.append(ReclaimOutcome(item: resolved, status: .deleted(bytes: bytes)))
                } catch {
                    outcomes.append(ReclaimOutcome(item: resolved, status: .failed(message: String(describing: error))))
                }
            case .cliCommand:
                outcomes.append(ReclaimOutcome(item: resolved, status: .failed(message: "cliCommand reclaim is out of Milestone 1 scope")))
            }
        }
        return outcomes
    }
}
