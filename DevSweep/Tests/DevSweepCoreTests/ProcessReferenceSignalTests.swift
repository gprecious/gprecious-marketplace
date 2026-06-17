import Testing
@testable import DevSweepCore

@Test func processSignalActiveWhenLsofHasOutput() async {
    let runner = MockCommandRunner(outputs: [
        "/usr/sbin/lsof": "COMMAND  PID  USER ...\nopenclaw 3788 x cwd DIR /Users/x/.openclaw-pyiri\n"
    ])
    let signal = ProcessReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.openclaw-pyiri") == true)
    #expect(signal.name == "process")
}

@Test func processSignalInactiveWhenLsofEmpty() async {
    let runner = MockCommandRunner(outputs: ["/usr/sbin/lsof": "   \n"])
    let signal = ProcessReferenceSignal(runner: runner)
    #expect(await signal.isActive(path: "/Users/x/.npm") == false)
}

@Test func processSignalUsesNonRecursiveLsofDirectoryProbe() async {
    let runner = ScriptedCommandRunner([
        "/usr/sbin/lsof +d /Users/x/project": [.init(stdout: "COMMAND PID USER\nnode 42 taejin\n")]
    ])
    let signal = ProcessReferenceSignal(runner: runner)

    #expect(await signal.isActive(path: "/Users/x/project") == true)
    #expect(await runner.calls == ["/usr/sbin/lsof +d /Users/x/project"])
}
