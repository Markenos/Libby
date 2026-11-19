import EventKit
import SwiftUI

/// Calendar events and reminders via EventKit.
final class EventKitSource: @unchecked Sendable {
    let store = EKEventStore()

    func requestCalendar() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func requestReminders() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    func events(from start: Date, days: Int) -> [EventItem] {
        let end = Calendar.current.date(byAdding: .day, value: days, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map { e in
                EventItem(
                    id: (e.eventIdentifier ?? UUID().uuidString) + "\(e.startDate.timeIntervalSince1970)",
                    title: e.title ?? "Untitled",
                    start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
                    location: e.location?.isEmpty == false ? e.location : nil,
                    calendar: e.calendar.title,
                    color: Color(nsColor: e.calendar.color ?? .controlAccentColor))
            }
            .sorted { $0.start < $1.start }
    }

    func reminders() async -> [ReminderItem] {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let raw: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
        }
        return raw.map { r in
            ReminderItem(
                id: r.calendarItemIdentifier,
                title: r.title ?? "Untitled",
                notes: r.notes?.isEmpty == false ? r.notes : nil,
                due: r.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                list: r.calendar.title,
                color: Color(nsColor: r.calendar.color ?? .controlAccentColor),
                isCompleted: r.isCompleted,
                priority: r.priority)
        }
        .sorted { a, b in
            switch (a.due, b.due) {
            case let (x?, y?): x < y
            case (_?, nil): true
            case (nil, _?): false
            default: a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    func setCompleted(id: String, _ done: Bool) throws {
        guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        r.isCompleted = done
        try store.save(r, commit: true)
    }
}
