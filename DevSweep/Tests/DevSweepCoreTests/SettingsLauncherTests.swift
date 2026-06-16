import Foundation
import Testing
@testable import DevSweepCore

/// 주입 가능한 stub은 호출 횟수를 기록한다(배너 "설정 열기" 경로가 정확히 1회 호출됨을 검증하는 데 사용).
private final class RecordingSettingsLauncher: SettingsLauncher, @unchecked Sendable {
    private(set) var callCount = 0
    func openFullDiskAccessSettings() { callCount += 1 }
}

@Suite struct SettingsLauncherTests {
    @Test func systemLauncherTargetsFullDiskAccessDeepLink() {
        #expect(
            SystemSettingsLauncher.fullDiskAccessSettingsURL.absoluteString
                == "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        )
    }

    @Test func recordingStubCountsCalls() {
        let launcher = RecordingSettingsLauncher()
        #expect(launcher.callCount == 0)
        launcher.openFullDiskAccessSettings()
        #expect(launcher.callCount == 1)
    }
}
