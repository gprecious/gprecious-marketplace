import Testing
@testable import DevSweepCore

@Test func launchdSignalActiveWhenPlistReferencesPath() async {
    let temp = TempDir()
    defer { temp.cleanup() }
    let agentsDir = temp.makeDir("LaunchAgents")
    temp.writeFile("LaunchAgents/com.openclaw.pyiri.plist",
                   "<plist><dict><key>OPENCLAW_HOME</key><string>/Users/x/.openclaw-pyiri</string></dict></plist>")

    let signal = LaunchdReferenceSignal(launchAgentsDir: agentsDir)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == true)
    #expect(await signal.isActive(path: "/Users/x/.npm") == false)
    #expect(signal.name == "launchd")
}

@Test func launchdSignalInactiveWhenAgentsDirMissing() async {
    let signal = LaunchdReferenceSignal(launchAgentsDir: "/nonexistent/LaunchAgents")
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == false)
}
