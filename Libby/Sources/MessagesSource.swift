import Foundation

/// Reads iMessage/SMS history from ~/Library/Messages/chat.db (read-only).
enum MessagesSource {
    static var databasePath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Messages/chat.db").path
    }

    static var hasAccess: Bool { DiskAccess.canRead(databasePath) }

    /// Messages stores dates as nanoseconds (or seconds on old rows) since 2001-01-01.
    static func date(_ raw: Int64) -> Date {
        let seconds = raw > 1_000_000_000_000 ? Double(raw) / 1_000_000_000 : Double(raw)
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    static func conversations(limit: Int = 150, names: ContactsResolver) throws -> [Conversation] {
        let db = try SQLiteDB(path: databasePath)
        let sql = """
        SELECT c.ROWID, c.display_name, c.chat_identifier, c.style,
               m.text, m.attributedBody, m.date, m.is_from_me, m.cache_has_attachments,
               (SELECT group_concat(h.id, '|') FROM chat_handle_join chj JOIN handle h ON h.ROWID = chj.handle_id WHERE chj.chat_id = c.ROWID),
               (SELECT count(*) FROM chat_message_join j2 JOIN message m2 ON m2.ROWID = j2.message_id
                  WHERE j2.chat_id = c.ROWID AND m2.is_read = 0 AND m2.is_from_me = 0 AND m2.associated_message_type = 0
                    AND m2.date > c.last_read_message_timestamp)
        FROM chat c
        JOIN (SELECT j.chat_id, max(j.message_date) AS last_date FROM chat_message_join j GROUP BY j.chat_id) lj ON lj.chat_id = c.ROWID
        JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID AND cmj.message_date = lj.last_date
        JOIN message m ON m.ROWID = cmj.message_id
        WHERE c.is_archived = 0
        GROUP BY c.ROWID
        ORDER BY lj.last_date DESC
        LIMIT ?
        """
        return try db.query(sql, [limit]) { r in
            let handles = (r.string(9) ?? "").split(separator: "|").map(String.init)
            let isGroup = r.int(3) == 43 || handles.count > 1
            let displayName = r.string(1) ?? ""
            let title: String
            if !displayName.isEmpty {
                title = displayName
            } else if handles.isEmpty {
                title = names.name(for: r.string(2) ?? "Unknown")
            } else {
                title = handles.map { names.name(for: $0, short: isGroup) }.joined(separator: ", ")
            }
            var text = messageText(text: r.string(4), body: r.data(5))
            if text.isEmpty && r.int(8) != 0 { text = "Attachment" }
            if r.int(7) != 0 && !text.isEmpty { text = "You: " + text }
            return Conversation(
                id: r.int(0), title: title, handles: handles, lastText: text,
                lastDate: date(r.int(6)), unread: Int(r.int(10)), isGroup: isGroup)
        }
    }

    static func messages(chatID: Int64, limit: Int = 200, names: ContactsResolver) throws -> [ChatMessage] {
        let db = try SQLiteDB(path: databasePath)
        let sql = """
        SELECT m.ROWID, m.text, m.attributedBody, m.date, m.is_from_me, h.id, m.cache_has_attachments
        FROM chat_message_join j
        JOIN message m ON m.ROWID = j.message_id
        LEFT JOIN handle h ON h.ROWID = m.handle_id
        WHERE j.chat_id = ? AND m.associated_message_type = 0 AND m.item_type = 0
        ORDER BY j.message_date DESC
        LIMIT ?
        """
        let rows: [ChatMessage] = try db.query(sql, [chatID, limit]) { r in
            var text = messageText(text: r.string(1), body: r.data(2))
            let attach = r.int(6) != 0
            if text.isEmpty && !attach { return nil }
            text = text.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return ChatMessage(
                id: r.int(0), text: text, date: date(r.int(3)), isFromMe: r.int(4) != 0,
                sender: r.string(5).map { names.name(for: $0, short: true) }, hasAttachment: attach)
        }
        return rows.reversed()
    }

    static func messageText(text: String?, body: Data?) -> String {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let body else { return "" }
        return decodeAttributedBody(body).replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Newer macOS versions store message text only in `attributedBody`, an NSArchiver
    /// "typedstream". The plain string follows the first "NSString" class marker.
    static func decodeAttributedBody(_ data: Data) -> String {
        let bytes = [UInt8](data)
        let marker = Array("NSString".utf8)
        guard let start = bytes.firstRange(of: marker)?.upperBound else { return "" }
        var i = start
        // Skip the class-info preamble up to the '+' (0x2B) string-type tag.
        while i < bytes.count, bytes[i] != 0x2B { i += 1 }
        i += 1
        guard i < bytes.count else { return "" }
        var length = Int(bytes[i]); i += 1
        if length == 0x81, i + 1 < bytes.count {
            length = Int(bytes[i]) | Int(bytes[i + 1]) << 8; i += 2
        } else if length == 0x82, i + 3 < bytes.count {
            length = Int(bytes[i]) | Int(bytes[i + 1]) << 8 | Int(bytes[i + 2]) << 16 | Int(bytes[i + 3]) << 24; i += 4
        }
        guard length > 0, i + length <= bytes.count else { return "" }
        return String(decoding: bytes[i..<(i + length)], as: UTF8.self)
    }
}
