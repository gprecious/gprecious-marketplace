/// Signal: is any process holding an open file directly under `path`? Uses non-recursive
/// `lsof +d <path>`; recursive `+D` is too expensive for large worktrees during scans.
/// Non-empty meaningful output ⇒ active. The command is mocked in tests.
public struct ProcessReferenceSignal: ActivitySignal {
    public let name = "process"
    private let runner: any CommandRunner

    public init(runner: any CommandRunner) {
        self.runner = runner
    }

    public func isActive(path: String) async -> Bool {
        let output = (try? await runner.run("/usr/sbin/lsof", ["+d", path])) ?? ""
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
