import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(greeting).font(.system(size: 34, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 4)

                GlassEffectContainer(spacing: 20) {
                    Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                        GridRow {
                            agenda
                            remindersCard
                        }
                        GridRow {
                            mailCard
                            messagesCard
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Cards

    private var agenda: some View {
        GlassCard(title: "Agenda", symbol: "calendar", action: { model.section = .calendar }) {
            let items = model.todaysEvents.filter { $0.title.matches(model.search) }
            if model.calendarState == .needsPermission {
                hint("Allow Calendar access in Settings")
            } else if items.isEmpty {
                hint("Nothing scheduled today")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.prefix(6)) { e in
                        HStack(alignment: .top, spacing: 12) {
                            Capsule().fill(e.color).frame(width: 4, height: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.title).lineLimit(1)
                                Text(e.timeText).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if e.start <= .now && e.end > .now && !e.isAllDay {
                                Text("Now").font(.caption.weight(.semibold)).foregroundStyle(e.color)
                            }
                        }
                        .contentShape(.rect)
                        .onTapGesture { model.open(e) }
                    }
                }
            }
        }
    }

    private var remindersCard: some View {
        GlassCard(title: "Due", symbol: "checklist", action: { model.section = .reminders }) {
            let items = model.reminders.filter { ($0.isOverdue || $0.isDueToday) && $0.title.matches(model.search) }
            if model.remindersState == .needsPermission {
                hint("Allow Reminders access in Settings")
            } else if items.isEmpty {
                hint("All clear")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.prefix(6)) { r in ReminderRow(reminder: r, compact: true) }
                }
            }
        }
    }

    private var mailCard: some View {
        GlassCard(title: "Unread mail", symbol: "envelope", action: { model.section = .mail }) {
            let items = model.mail.filter { !$0.isRead && ($0.subject.matches(model.search) || $0.sender.matches(model.search)) }
            if model.mailState == .needsPermission {
                hint("Needs Full Disk Access")
            } else if items.isEmpty {
                hint("Inbox zero")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.prefix(5)) { m in
                        HStack(spacing: 12) {
                            Avatar(name: m.sender, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.sender).font(.subheadline.weight(.medium)).lineLimit(1)
                                Text(m.subject).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(m.date.shortStamp).font(.caption2).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                        .onTapGesture { model.open(m) }
                    }
                }
            }
        }
    }

    private var messagesCard: some View {
        GlassCard(title: "Messages", symbol: "message", action: { model.section = .messages }) {
            let items = model.conversations.filter { $0.title.matches(model.search) || $0.lastText.matches(model.search) }
            if model.messagesState == .needsPermission {
                hint("Needs Full Disk Access")
            } else if items.isEmpty {
                hint("No recent conversations")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.prefix(5)) { c in
                        HStack(spacing: 12) {
                            Avatar(name: c.title, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.title).font(.subheadline.weight(c.unread > 0 ? .semibold : .medium)).lineLimit(1)
                                Text(c.lastText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if c.unread > 0 { Circle().fill(Color.accentColor).frame(width: 7, height: 7) }
                            Text(c.lastDate.shortStamp).font(.caption2).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                        .onTapGesture { model.section = .messages }
                    }
                }
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    }
}
