import AppKit
import EventKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    var section: AppSection = .today
    var search = ""

    var mail: [MailItem] = []
    var conversations: [Conversation] = []
    var events: [EventItem] = []
    var reminders: [ReminderItem] = []

    var mailState: SourceState = .idle
    var messagesState: SourceState = .idle
    var calendarState: SourceState = .idle
    var remindersState: SourceState = .idle
    var lastRefresh: Date?

    let eventKit = EventKitSource()
    let contacts = ContactsResolver()
    private var contactsLoaded = false
    private var isRefreshing = false

    var unreadMail: Int { mail.filter { !$0.isRead }.count }
    var unreadMessages: Int { conversations.reduce(0) { $0 + ($1.unread > 0 ? 1 : 0) } }
    var dueReminders: [ReminderItem] { reminders.filter { !$0.isCompleted && ($0.isOverdue || $0.isDueToday) } }
    var todaysEvents: [EventItem] {
        events.filter { Calendar.current.isDateInToday($0.start) || ($0.start < .now && $0.end > .now) }
    }

    func count(for s: AppSection) -> Int {
        switch s {
        case .mail: unreadMail
        case .messages: unreadMessages
        case .reminders: dueReminders.count
        default: 0
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false; lastRefresh = .now }

        if !contactsLoaded {
            await contacts.load()
            contactsLoaded = true
        }
        async let a: Void = loadCalendar()
        async let b: Void = loadReminders()
        async let c: Void = loadMail()
        async let d: Void = loadMessages()
        _ = await (a, b, c, d)
    }

    private func loadCalendar() async {
        if calendarState != .ready { calendarState = .loading }
        guard await eventKit.requestCalendar() else { calendarState = .needsPermission; return }
        let start = Calendar.current.startOfDay(for: .now)
        let kit = eventKit
        events = await Task.detached { kit.events(from: start, days: 14) }.value
        calendarState = .ready
    }

    private func loadReminders() async {
        if remindersState != .ready { remindersState = .loading }
        guard await eventKit.requestReminders() else { remindersState = .needsPermission; return }
        reminders = await eventKit.reminders()
        remindersState = .ready
    }

    private func loadMail() async {
        if mailState != .ready { mailState = .loading }
        let result: Result<[MailItem], Error>? = await Task.detached {
            guard MailSource.hasAccess else { return nil }
            return Result { try MailSource.load() }
        }.value
        switch result {
        case nil: mailState = .needsPermission
        case .success(let items): mail = items; mailState = .ready
        case .failure(let e): mailState = .failed("\(e)")
        }
    }

    private func loadMessages() async {
        if messagesState != .ready { messagesState = .loading }
        let names = contacts
        let result: Result<[Conversation], Error>? = await Task.detached {
            guard MessagesSource.hasAccess else { return nil }
            return Result { try MessagesSource.conversations(names: names) }
        }.value
        switch result {
        case nil: messagesState = .needsPermission
        case .success(let items): conversations = items; messagesState = .ready
        case .failure(let e): messagesState = .failed("\(e)")
        }
    }

    func messages(in chat: Conversation) async -> [ChatMessage] {
        let names = contacts
        return await Task.detached { (try? MessagesSource.messages(chatID: chat.id, names: names)) ?? [] }.value
    }

    func toggle(_ reminder: ReminderItem) {
        guard let i = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        let done = !reminders[i].isCompleted
        withAnimation(.smooth) { reminders[i].isCompleted = done }
        try? eventKit.setCompleted(id: reminder.id, done)
    }

    // MARK: Opening things in Apple's apps

    func open(_ item: MailItem) {
        if let url = item.mailURL { NSWorkspace.shared.open(url) } else { openApp("com.apple.mail") }
    }

    func open(_ chat: Conversation) {
        if !chat.isGroup, let h = chat.handles.first, let url = URL(string: "imessage://\(h)") {
            NSWorkspace.shared.open(url)
        } else {
            openApp("com.apple.MobileSMS")
        }
    }

    func open(_ event: EventItem) {
        let t = event.start.timeIntervalSinceReferenceDate
        if let url = URL(string: "ical://ekevent/\(t)") , NSWorkspace.shared.open(url) { return }
        openApp("com.apple.iCal")
    }

    func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openPrivacySettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension String {
    func matches(_ query: String) -> Bool {
        query.isEmpty || localizedCaseInsensitiveContains(query)
    }
}
