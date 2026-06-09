import Foundation
import Testing
@testable import DevSweepCore

/// Test double for FileSystemDeleter. Records every call and DELETES NOTHING.
/// Returns the configured byte count so callers can assert reclaim accounting.
actor RecordingDeleter: FileSystemDeleter {
    struct Call: Equatable { let path: String; let toTrash: Bool }
    private(set) var calls: [Call] = []
    private let bytesPerCall: Int64

    init(bytesPerCall: Int64 = 0) { self.bytesPerCall = bytesPerCall }

    func delete(path: String, toTrash: Bool) async throws -> Int64 {
        calls.append(Call(path: path, toTrash: toTrash))
        return bytesPerCall
    }

    var callCount: Int { calls.count }
}

@Test func recordingDeleterRecordsAndDeletesNothing() async throws {
    let deleter = RecordingDeleter(bytesPerCall: 100)
    let bytes = try await deleter.delete(path: "/tmp/x", toTrash: true)
    #expect(bytes == 100)
    #expect(await deleter.callCount == 1)
    #expect(await deleter.calls.first == .init(path: "/tmp/x", toTrash: true))
}
