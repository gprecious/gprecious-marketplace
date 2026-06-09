import Testing
@testable import DevSweepCore

@Test func crontabSignalActiveWhenLineReferencesPath() async {
    let runner = MockCommandRunner(outputs: [
        "/usr/bin/crontab": "0 3 * * * find /Users/x/.openclaw-pyiri/logs -name '*.log' -mtime +7 -delete\n"
    ])
    let signal = CrontabReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == true)
    #expect(signal.name == "crontab")
}

@Test func crontabSignalInactiveWhenNoReference() async {
    let runner = MockCommandRunner(outputs: ["/usr/bin/crontab": "0 9 * * * /Users/x/other/run.sh\n"])
    let signal = CrontabReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == false)
}
