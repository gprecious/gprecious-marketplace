import Foundation
import SQLite3

/// File-backed `Store` on top of the system SQLite (`import SQLite3`). An `actor` so every
/// C-API call is serialized on a single executor. Tables are created on `init`; reopening the
/// same path sees previously committed rows (each write autocommits, so durability does not
/// depend on closing the connection).
public actor SQLiteStore: Store {
    public enum StoreError: Error, Equatable {
        case open(String)
        case createTables(String)
    }

    /// `nonisolated(unsafe)` because the handle is a C pointer (non-Sendable): the actor still
    /// serializes every method that touches it, and `deinit` runs only when no references remain,
    /// so there is never concurrent access — but the compiler can't prove that for a raw pointer.
    private nonisolated(unsafe) var db: OpaquePointer?

    /// SQLite copies text/blob binds only when the destructor is `SQLITE_TRANSIENT` (== -1).
    /// That symbol isn't imported into Swift, so reconstruct it by bit pattern.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK, let opened = handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open failed"
            sqlite3_close(handle)
            throw StoreError.open(message)
        }
        do {
            try Self.createTables(opened)
        } catch {
            sqlite3_close(opened)
            throw error
        }
        db = opened
    }

    deinit {
        sqlite3_close(db)
    }

    /// `static` (not actor-isolated) so it can run against the freshly opened handle inside the
    /// synchronous initializer, before `db` is assigned.
    private static func createTables(_ db: OpaquePointer?) throws {
        try exec(db, """
        CREATE TABLE IF NOT EXISTS scans (
            id TEXT PRIMARY KEY,
            ts REAL,
            total INTEGER,
            per_module TEXT
        );
        """)
        try exec(db, """
        CREATE TABLE IF NOT EXISTS audits (
            ts REAL,
            item_id TEXT,
            module_id TEXT,
            method TEXT,
            bytes INTEGER,
            status TEXT
        );
        """)
    }

    private static func exec(_ db: OpaquePointer?, _ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "sqlite3_exec failed"
            sqlite3_free(errorPointer)
            throw StoreError.createTables(message)
        }
    }

    // MARK: - Store

    public func recordScan(_ record: ScanRecord) async {
        let json = (try? JSONEncoder().encode(record.perModule))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        withStatement("INSERT OR REPLACE INTO scans (id, ts, total, per_module) VALUES (?, ?, ?, ?);") { stmt in
            bindText(stmt, 1, record.id)
            sqlite3_bind_double(stmt, 2, record.timestamp.timeIntervalSince1970)
            sqlite3_bind_int64(stmt, 3, record.totalBytes)
            bindText(stmt, 4, json)
            _ = sqlite3_step(stmt)
        }
    }

    public func recordAudit(_ records: [AuditRecord]) async {
        for record in records {
            withStatement("INSERT INTO audits (ts, item_id, module_id, method, bytes, status) VALUES (?, ?, ?, ?, ?, ?);") { stmt in
                sqlite3_bind_double(stmt, 1, record.timestamp.timeIntervalSince1970)
                bindText(stmt, 2, record.itemId)
                if let moduleId = record.moduleId {
                    bindText(stmt, 3, moduleId)
                } else {
                    sqlite3_bind_null(stmt, 3)
                }
                bindText(stmt, 4, record.method)
                sqlite3_bind_int64(stmt, 5, record.bytesReclaimed)
                bindText(stmt, 6, record.status)
                _ = sqlite3_step(stmt)
            }
        }
    }

    public func recentScans(limit: Int) async -> [ScanRecord] {
        var result: [ScanRecord] = []
        withStatement("SELECT id, ts, per_module FROM scans ORDER BY ts DESC LIMIT ?;") { stmt in
            sqlite3_bind_int(stmt, 1, Int32(max(0, limit)))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = columnText(stmt, 0) ?? ""
                let ts = sqlite3_column_double(stmt, 1)
                let per = decodePerModule(columnText(stmt, 2) ?? "{}")
                result.append(ScanRecord(id: id, timestamp: Date(timeIntervalSince1970: ts), perModule: per))
            }
        }
        return result
    }

    public func auditLog(limit: Int) async -> [AuditRecord] {
        var result: [AuditRecord] = []
        withStatement("SELECT ts, item_id, module_id, method, bytes, status FROM audits ORDER BY ts DESC LIMIT ?;") { stmt in
            sqlite3_bind_int(stmt, 1, Int32(max(0, limit)))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let ts = sqlite3_column_double(stmt, 0)
                let itemId = columnText(stmt, 1) ?? ""
                let moduleId = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : columnText(stmt, 2)
                let method = columnText(stmt, 3) ?? ""
                let bytes = sqlite3_column_int64(stmt, 4)
                let status = columnText(stmt, 5) ?? ""
                result.append(AuditRecord(timestamp: Date(timeIntervalSince1970: ts), itemId: itemId,
                                          moduleId: moduleId, method: method, bytesReclaimed: bytes, status: status))
            }
        }
        return result
    }

    public func latestScan() async -> ScanRecord? {
        await recentScans(limit: 1).first
    }

    // MARK: - C helpers

    /// Prepare → run `body` → finalize. Statements are not cached, so they always finalize,
    /// which keeps `sqlite3_close` from returning SQLITE_BUSY at deinit.
    private func withStatement(_ sql: String, _ body: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return
        }
        body(stmt)
        sqlite3_finalize(stmt)
    }

    private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, Self.transient)
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    private func decodePerModule(_ json: String) -> [String: Int64] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int64].self, from: data) else { return [:] }
        return decoded
    }
}
