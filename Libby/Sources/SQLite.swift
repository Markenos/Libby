import Foundation
import SQLite3

/// A tiny read-only SQLite wrapper. Opens databases immutable so Mail/Messages are never touched.
final class SQLiteDB {
    private var handle: OpaquePointer?

    enum Failure: Error { case cannotOpen(String), query(String) }

    init(path: String) throws {
        let uri = "file:\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)?mode=ro"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(uri, &handle, flags, nil) == SQLITE_OK else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw Failure.cannotOpen(msg)
        }
        sqlite3_busy_timeout(handle, 2000)
    }

    deinit { sqlite3_close(handle) }

    struct Row {
        let stmt: OpaquePointer
        func int(_ i: Int32) -> Int64 { sqlite3_column_int64(stmt, i) }
        func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
        func isNull(_ i: Int32) -> Bool { sqlite3_column_type(stmt, i) == SQLITE_NULL }
        func string(_ i: Int32) -> String? {
            guard let c = sqlite3_column_text(stmt, i) else { return nil }
            return String(cString: c)
        }
        func data(_ i: Int32) -> Data? {
            guard let b = sqlite3_column_blob(stmt, i) else { return nil }
            return Data(bytes: b, count: Int(sqlite3_column_bytes(stmt, i)))
        }
    }

    func query<T>(_ sql: String, _ binds: [Any] = [], map: (Row) -> T?) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw Failure.query(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, v) in binds.enumerated() {
            let idx = Int32(i + 1)
            switch v {
            case let n as Int: sqlite3_bind_int64(stmt, idx, Int64(n))
            case let n as Int64: sqlite3_bind_int64(stmt, idx, n)
            case let s as String: sqlite3_bind_text(stmt, idx, s, -1, transient)
            default: sqlite3_bind_null(stmt, idx)
            }
        }
        var out: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let v = map(Row(stmt: stmt)) { out.append(v) }
        }
        return out
    }
}

enum DiskAccess {
    /// True when the app can read a file protected by Full Disk Access.
    static func canRead(_ path: String) -> Bool {
        FileManager.default.isReadableFile(atPath: path) && (try? SQLiteDB(path: path)) != nil
            && ((try? SQLiteDB(path: path).query("select 1 from sqlite_master limit 1") { _ in 1 }) != nil)
    }
}
