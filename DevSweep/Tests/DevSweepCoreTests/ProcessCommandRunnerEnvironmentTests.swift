import Testing
@testable import DevSweepCore

@Test func processCommandRunnerAddsMacDeveloperPathsToRestrictedGuiPath() async throws {
    let runner = ProcessCommandRunner(environment: ["PATH": "/usr/bin:/bin"])

    let path = try await runner.run("/usr/bin/env", ["sh", "-lc", "printf %s \"$PATH\""])
    let entries = path.split(separator: ":").map(String.init)

    #expect(entries.contains("/opt/homebrew/bin"))
    #expect(entries.contains("/usr/local/bin"))
    #expect(entries.contains("/usr/bin"))
    #expect(entries.contains("/bin"))
}
