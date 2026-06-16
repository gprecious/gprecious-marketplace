import AppKit

/// FDA 설정 패널 딥링크를 여는 IO 추상화. 주입 가능 → 테스트는 호출 기록 stub.
/// (spec §3.3은 DevSweepApp이라 적었으나, 테스트 타깃이 없어 DevSweepCore로 이동 — `FullDiskAccessProbe`와
/// 동일하게 "시스템 접근" IO를 Core에 모은다.)
public protocol SettingsLauncher: Sendable {
    func openFullDiskAccessSettings()
}

/// `NSWorkspace`로 시스템 설정의 Full Disk Access 패널을 연다. 열기 실패 시 조용히 무시.
public struct SystemSettingsLauncher: SettingsLauncher {
    /// 시스템 설정 > 개인정보 보호 및 보안 > 전체 디스크 접근 권한 딥링크.
    public static let fullDiskAccessSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )!

    public init() {}

    public func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(Self.fullDiskAccessSettingsURL)
    }
}
