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
