/// stdout + 종료 코드. CLI 회수 성공 판정에 필요.
public struct CommandResult: Sendable, Equatable {
    public let stdout: String
    public let exitCode: Int32

    public init(stdout: String, exitCode: Int32) {
        self.stdout = stdout
        self.exitCode = exitCode
    }
}

/// Abstraction over running an external command. `runResult` is the requirement;
/// `run` is a convenience default (stdout only) so M1 call sites (lsof, crontab) are
/// unchanged.
public protocol CommandRunner: Sendable {
    /// Run `executable` with `args`, returning stdout + exit code.
    /// A non-zero exit does NOT throw; it is reported via `CommandResult.exitCode`.
    func runResult(_ executable: String, _ args: [String]) async throws -> CommandResult

    /// Convenience: stdout only. Default implementation delegates to `runResult`.
    func run(_ executable: String, _ args: [String]) async throws -> String
}

extension CommandRunner {
    public func run(_ executable: String, _ args: [String]) async throws -> String {
        try await runResult(executable, args).stdout
    }
}
