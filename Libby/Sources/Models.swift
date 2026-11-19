import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today, mail, messages, calendar, reminders
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .mail: "Mail"
        case .messages: "Messages"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        }
    }

    var tint: Color {
        switch self {
        case .today: .indigo
        case .mail: .blue
        case .messages: .green
        case .calendar: .red
        case .reminders: .orange
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .mail: "envelope.fill"
        case .messages: "message.fill"
        case .calendar: "calendar"
        case .reminders: "checklist.checked"
        }
    }
}

struct MailItem: Identifiable, Hashable {
    let id: Int64
    let sender: String
    let senderAddress: String
    let subject: String
    let preview: String
    let date: Date
    var isRead: Bool
    var isFlagged: Bool
    let mailbox: String
    let mailboxURL: String?
    let messageIDHeader: String?

    /// Where Mail's AppleScript can find this message: account UUID, mailbox path, Message-ID.
    var location: (account: String, mailbox: String, messageID: String)? {
        guard let url = mailboxURL, let header = messageIDHeader, !header.isEmpty,
              let schemeEnd = url.range(of: "://") else { return nil }
        let rest = url[schemeEnd.upperBound...]
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        let account = String(rest[..<slash])
        let path = String(rest[rest.index(after: slash)...]).removingPercentEncoding ?? ""
        guard !account.isEmpty, !path.isEmpty else { return nil }
        let mid = header.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
        return (account, path, mid)
    }

    /// Opens the message in Mail.app.
    var mailURL: URL? {
        guard var h = messageIDHeader, !h.isEmpty else { return nil }
        h = h.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let enc = h.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: "@.-_"))) ?? h
        return URL(string: "message://%3C\(enc)%3E")
    }
}

struct Conversation: Identifiable, Hashable {
    let id: Int64
    let guid: String
    let title: String
    let handles: [String]
    let lastText: String
    let lastDate: Date
    let unread: Int
    let isGroup: Bool
}

struct ChatMessage: Identifiable, Hashable {
    let id: Int64
    let text: String
    let date: Date
    let isFromMe: Bool
    let sender: String?
    let hasAttachment: Bool
}

struct EventItem: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let calendar: String
    let color: Color
}

struct ReminderItem: Identifiable, Hashable {
    let id: String
    let title: String
    let notes: String?
    let due: Date?
    let list: String
    let color: Color
    var isCompleted: Bool
    let priority: Int

    var isOverdue: Bool { (due.map { $0 < Calendar.current.startOfDay(for: .now) }) ?? false }
    var isDueToday: Bool { due.map { Calendar.current.isDateInToday($0) } ?? false }
}

enum SourceState: Equatable {
    case idle, loading, ready, needsPermission, failed(String)
}
