import Testing
@testable import DevSweepCore

@Test func menuActionPresentationExplainsDryRunBlockedByMissingFullDiskAccess() {
    let presentation = MenuActionPresentation(
        hasFullDiskAccess: false,
        isScanning: false,
        isReclaiming: false,
        currentItemCount: 0,
        hasDisplayedResults: true
    )

    #expect(presentation.scanDisabled)
    #expect(presentation.reclaimDisabled)
    #expect(presentation.unavailableMessage == "전체 디스크 접근 권한을 허용한 뒤 다시 스캔하면 미리보기를 실행할 수 있습니다.")
}

@Test func menuActionPresentationExplainsStoredSummaryWithoutDetailedItems() {
    let presentation = MenuActionPresentation(
        hasFullDiskAccess: true,
        isScanning: false,
        isReclaiming: false,
        currentItemCount: 0,
        hasDisplayedResults: true
    )

    #expect(presentation.scanDisabled == false)
    #expect(presentation.reclaimDisabled)
    #expect(presentation.unavailableMessage == "저장된 요약만 표시 중입니다. 지금 스캔 후 미리보기를 실행하세요.")
}

@Test func menuActionPresentationEnablesDryRunWhenDetailedItemsExist() {
    let presentation = MenuActionPresentation(
        hasFullDiskAccess: true,
        isScanning: false,
        isReclaiming: false,
        currentItemCount: 3,
        hasDisplayedResults: true
    )

    #expect(presentation.scanDisabled == false)
    #expect(presentation.reclaimDisabled == false)
    #expect(presentation.unavailableMessage == nil)
}

@Test func menuActionPresentationLabelsDryRunWhileReclaiming() {
    let presentation = MenuActionPresentation(
        hasFullDiskAccess: true,
        isScanning: false,
        isReclaiming: true,
        currentItemCount: 3,
        hasDisplayedResults: true
    )

    #expect(presentation.previewButtonTitle == "미리보기 중…")
    #expect(presentation.previewButtonSystemImage == nil)
    #expect(presentation.showsReclaimProgress)
}
