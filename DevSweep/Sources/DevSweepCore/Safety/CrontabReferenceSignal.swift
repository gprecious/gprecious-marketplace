/// Signal: does the user's crontab reference `path`? A scheduled job touching the path
/// means it is in active use. Output of `crontab -l` is mocked in tests.
public struct CrontabReferenceSignal: ActivitySignal {
    public let name = "crontab"
    private let runner: any CommandRunner

    public init(runner: any CommandRunner) {
        self.runner = runner
    }

    public func isActive(path: String) async -> Bool {
        let output = (try? await runner.run("/usr/bin/crontab", ["-l"])) ?? ""
        return output.contains(path)
    }
}
