import SwiftUI

struct CalendarView: View {
    @Environment(AppModel.self) private var model

    private var days: [(Date, [EventItem])] {
        let filtered = model.events.filter { $0.title.matches(model.search) || ($0.location ?? "").matches(model.search) }
        let grouped = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: max($0.start, Calendar.current.startOfDay(for: .now))) }
        return grouped.keys.sorted().map { ($0, grouped[$0]!) }
    }

    var body: some View {
        SourceGate(state: model.calendarState, permission: AnyView(
            PermissionPanel(symbol: "calendar", title: "Calendar access is off",
                            message: "Allow Libby to see your calendars in Privacy & Security › Calendars.",
                            buttonTitle: "Open Settings",
                            action: { AppModel.openPrivacySettings("Privacy_Calendars") }))) {
            if days.isEmpty {
                EmptyState(symbol: "calendar", text: "Nothing in the next two weeks")
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(days, id: \.0) { day, events in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(day.dayHeading)
                                        .font(.headline)
                                        .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.accentColor : .primary)
                                    ForEach(events) { e in EventRow(event: e).onTapGesture { model.open(e) } }
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                            }
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct EventRow: View {
    let event: EventItem
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Capsule().fill(event.color).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                HStack(spacing: 6) {
                    if !event.isAllDay { Text(event.timeText) }
                    if let loc = event.location { Text("· \(loc)").lineLimit(1) }
                }
                .font(.caption).foregroundStyle(.secondary)
                Text(event.calendar).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(.rect)
    }
}
