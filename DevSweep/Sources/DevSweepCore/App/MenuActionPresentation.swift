/// Pure action-state rules for the menubar menu. Kept outside SwiftUI so disabled actions can
/// explain why they are unavailable instead of feeling unresponsive.
public struct MenuActionPresentation: Sendable, Equatable {
    public let scanDisabled: Bool
    public let reclaimDisabled: Bool
    public let unavailableMessage: String?

    public init(
        hasFullDiskAccess: Bool,
        isScanning: Bool,
        isReclaiming: Bool,
        currentItemCount: Int,
        hasDisplayedResults: Bool
    ) {
        self.scanDisabled = isScanning || !hasFullDiskAccess
        self.reclaimDisabled = !hasFullDiskAccess || isScanning || isReclaiming || currentItemCount == 0

        if !hasFullDiskAccess {
            self.unavailableMessage = "전체 디스크 접근 권한을 허용한 뒤 다시 스캔하면 미리보기를 실행할 수 있습니다."
        } else if currentItemCount == 0, hasDisplayedResults {
            self.unavailableMessage = "저장된 요약만 표시 중입니다. 지금 스캔 후 미리보기를 실행하세요."
        } else {
            self.unavailableMessage = nil
        }
    }
}
