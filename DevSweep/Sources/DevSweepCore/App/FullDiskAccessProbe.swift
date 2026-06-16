import Foundation

/// Full Disk Access 권한 유무. FDA는 자동 요청 API가 없으므로 granted/denied 2-상태만 의미가 있다.
public enum FDAStatus: Sendable, Equatable {
    case granted
    case denied
}

/// 주입 가능한 FDA probe. 단위 테스트는 고정 상태를 반환하는 stub을 쓴다.
public protocol FullDiskAccessProbe: Sendable {
    func check() -> FDAStatus
}

/// `~/Library/Application Support/com.apple.TCC/TCC.db`를 `open(O_RDONLY)` 시도해 FDA를 판정한다.
/// 파일 내용은 읽지 않는다(권한 체크용 fd만). `fd >= 0`이면 `close` 후 `.granted`; 그 외 *모든*
/// 결과(EPERM/EACCES/ENOENT/경로 변경 등)는 fail-safe `.denied`(무권한 방치 < 배너 한 번 더).
public struct TCCDatabaseProbe: FullDiskAccessProbe {
    private let path: String

    public init(path: String = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db") {
        self.path = path
    }

    public func check() -> FDAStatus {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return .denied }
        close(fd)
        return .granted
    }
}
