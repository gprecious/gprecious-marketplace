/// Abstraction over running an external command and capturing stdout. Injected into
/// signals that wrap shell tools (lsof, crontab) so their parsing is unit-testable.
public protocol CommandRunner: Sendable {
    /// Run `executable` with `args`, returning stdout as a UTF-8 string.
    /// A non-zero exit returns whatever stdout was captured (does not throw on exit code).
    func run(_ executable: String, _ args: [String]) async throws -> String
}
