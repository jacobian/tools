import Foundation
import SQLite3

// SQLite needs to be told to copy the string a binding points at, since the
// Swift value backing it dies at the end of the call.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLValue {
    case null
    case int(Int64)
    case text(String)

    /// Empty text stores as NULL, matching how the schema means "not filled in".
    static func optionalText(_ s: String) -> SQLValue {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .null : .text(trimmed)
    }

    static func optionalInt(_ i: Int64?) -> SQLValue {
        i.map { .int($0) } ?? .null
    }
}

struct Row {
    private let values: [String: SQLValue]

    init(_ values: [String: SQLValue]) { self.values = values }

    func int(_ column: String) -> Int64? {
        if case .int(let v)? = values[column] { return v }
        return nil
    }

    /// NULL reads back as "" -- the forms bind to plain strings throughout.
    func string(_ column: String) -> String {
        if case .text(let v)? = values[column] { return v }
        return ""
    }
}

struct DatabaseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class Database {
    private var handle: OpaquePointer?

    init(path: String) throws {
        var h: OpaquePointer?
        guard sqlite3_open(path, &h) == SQLITE_OK, let h else {
            let detail = h.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(h)
            throw DatabaseError(message: "Couldn't open \(path): \(detail)")
        }
        handle = h
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit { sqlite3_close(handle) }

    func query(_ sql: String, _ params: [SQLValue] = []) throws -> [Row] {
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }

        var rows: [Row] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else { throw lastError() }

            var values: [String: SQLValue] = [:]
            for i in 0..<sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER:
                    values[name] = .int(sqlite3_column_int64(stmt, i))
                case SQLITE_NULL:
                    values[name] = .null
                default:
                    if let c = sqlite3_column_text(stmt, i) {
                        values[name] = .text(String(cString: c))
                    } else {
                        values[name] = .null
                    }
                }
            }
            rows.append(Row(values))
        }
        return rows
    }

    /// Returns the rowid of an INSERT; meaningless for other statements.
    @discardableResult
    func execute(_ sql: String, _ params: [SQLValue] = []) throws -> Int64 {
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
        return sqlite3_last_insert_rowid(handle)
    }

    private func prepare(_ sql: String, _ params: [SQLValue]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw lastError()
        }
        for (i, param) in params.enumerated() {
            let position = Int32(i + 1)
            let result: Int32
            switch param {
            case .null:
                result = sqlite3_bind_null(stmt, position)
            case .int(let v):
                result = sqlite3_bind_int64(stmt, position, v)
            case .text(let v):
                result = sqlite3_bind_text(stmt, position, v, -1, SQLITE_TRANSIENT)
            }
            guard result == SQLITE_OK else {
                sqlite3_finalize(stmt)
                throw lastError()
            }
        }
        return stmt
    }

    private func lastError() -> DatabaseError {
        DatabaseError(message: String(cString: sqlite3_errmsg(handle)))
    }
}
