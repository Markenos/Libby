import Foundation

/// Reads recent messages from Mail.app's local "Envelope Index" database (read-only).
enum MailSource {
    static var databasePath: String? {
        let base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: base.path) else { return nil }
        let versions = dirs.filter { $0.hasPrefix("V") }
            .compactMap { name -> (Int, String)? in Int(name.dropFirst()).map { ($0, name) } }
            .sorted { $0.0 > $1.0 }
        for (_, name) in versions {
            let p = base.appendingPathComponent(name).appendingPathComponent("MailData/Envelope Index").path
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return nil
    }

    static var hasAccess: Bool { databasePath.map(DiskAccess.canRead) ?? false }

    static func load(limit: Int = 300) throws -> [MailItem] {
        guard let path = databasePath else { return [] }
        let db = try SQLiteDB(path: path)
        // All received mail (Gmail keeps most of it in "All Mail"); skip sent, drafts, trash and junk.
        let sql = """
        SELECT m.ROWID, a.address, a.comment, s.subject, IFNULL(su.summary, ''),
               COALESCE(m.display_date, m.date_received, m.date_sent, 0),
               m.read, m.flagged, mb.url, g.message_id_header
        FROM messages m
        JOIN subjects s ON s.ROWID = m.subject
        LEFT JOIN addresses a ON a.ROWID = m.sender
        LEFT JOIN summaries su ON su.ROWID = m.summary
        LEFT JOIN mailboxes mb ON mb.ROWID = m.mailbox
        LEFT JOIN message_global_data g ON g.ROWID = m.global_message_id
        WHERE m.deleted = 0
          AND lower(mb.url) NOT LIKE '%sent%'
          AND lower(mb.url) NOT LIKE '%draft%'
          AND lower(mb.url) NOT LIKE '%deleted%'
          AND lower(mb.url) NOT LIKE '%trash%'
          AND lower(mb.url) NOT LIKE '%5bgmail%5d/bin'
          AND lower(mb.url) NOT LIKE '%junk%'
          AND lower(mb.url) NOT LIKE '%spam%'
          AND lower(mb.url) NOT LIKE '%outbox%'
        ORDER BY COALESCE(m.display_date, m.date_received) DESC
        LIMIT ?
        """
        var seen = Set<String>()
        return try db.query(sql, [limit]) { r in
            let address = r.string(1) ?? ""
            let comment = r.string(2) ?? ""
            let subject = (r.string(3) ?? "").trimmingCharacters(in: .whitespaces)
            let header = r.string(9)
            // The same message can be indexed in several mailboxes (e.g. Gmail labels).
            let key = header ?? "\(address)|\(subject)|\(r.int(5))"
            guard seen.insert(key).inserted else { return nil }
            return MailItem(
                id: r.int(0),
                sender: comment.isEmpty ? address : comment,
                senderAddress: address,
                subject: subject.isEmpty ? "(No subject)" : subject,
                preview: (r.string(4) ?? "").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces),
                date: Date(timeIntervalSince1970: TimeInterval(r.int(5))),
                isRead: r.int(6) != 0,
                isFlagged: r.int(7) != 0,
                mailbox: mailboxName(r.string(8)),
                mailboxURL: r.string(8),
                messageIDHeader: header
            )
        }
    }

    private static func mailboxName(_ url: String?) -> String {
        guard let url, let last = url.split(separator: "/").last else { return "Inbox" }
        return last.removingPercentEncoding ?? String(last)
    }
}
