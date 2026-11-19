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

    private var nextEvent: EventItem? {
        model.events.first { !$0.isAllDay && $0.end > .now }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                GlassEffectContainer(spacing: 18) {
                    VStack(spacing: 18) {
                        stats
                        if let e = nextEvent { upNext(e) }
                        Grid(horizontalSpacing: 18, verticalSpacing: 18) {
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
            }
            .padding(28)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Header & summary

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(greeting).font(.system(size: 38, weight: .bold, design: .rounded))
            }
            Spacer()
            if let last = model.lastRefresh {
                Label("Updated \(last.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.icloud")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .glassEffect()
            }
        }
        .padding(.horizontal, 4)
    }

    private var stats: some View {
        HStack(spacing: 14) {
            StatPill(value: model.todaysEvents.count, label: "events today", symbol: AppSection.calendar.symbol,
                     tint: AppSection.calendar.tint) { model.section = .calendar }
            StatPill(value: model.dueReminders.count, label: "reminders due", symbol: AppSection.reminders.symbol,
                     tint: AppSection.reminders.tint) { model.section = .reminders }
            StatPill(value: model.unreadMail, label: "unread emails", symbol: AppSection.mail.symbol,
                     tint: AppSection.mail.tint) { model.section = .mail }
            StatPill(value: model.unreadMessages, label: "unread chats", symbol: AppSection.messages.symbol,
                     tint: AppSection.messages.tint) { model.section = .messages }
        }
    }

    private func upNext(_ e: EventItem) -> some View {
        let isNow = e.start <= .now
        return HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isNow ? "HAPPENING NOW" : "UP NEXT")
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(e.color)
                Text(e.title).font(.system(size: 24, weight: .semibold, design: .rounded)).lineLimit(1)
                HStack(spacing: 10) {
                    Label(e.timeText, systemImage: "clock")
                    if let loc = e.location { Label(loc, systemImage: "mappin.and.ellipse").lineLimit(1) }
                    Label(e.calendar, systemImage: "calendar")
                }
                .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(isNow ? e.end : e.start, style: .relative)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(isNow ? "left" : "to go").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .glassEffect(.regular.tint(e.color.opacity(0.35)), in: .rect(cornerRadius: 20))
        }
        .padding(24)
        .glassEffect(.regular.tint(e.color.opacity(0.14)).interactive(), in: .rect(cornerRadius: 30))
        .onTapGesture { model.open(e) }
    }

    // MARK: Cards

    private var agenda: some View {
        let items = model.todaysEvents.filter { $0.title.matches(model.search) }
        return GlassCard(title: "Agenda", symbol: AppSection.calendar.symbol, tint: AppSection.calendar.tint,
                         subtitle: items.isEmpty ? nil : "\(items.count) today",
                         action: { model.section = .calendar }) {
            if model.calendarState == .needsPermission {
                hint("Allow Calendar access in Settings", symbol: "lock")
            } else if items.isEmpty {
                hint("Nothing scheduled today", symbol: "sun.horizon")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.prefix(6)) { e in
                        HStack(alignment: .center, spacing: 12) {
                            Capsule().fill(e.color.gradient).frame(width: 5, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.title).font(.callout.weight(.medium)).lineLimit(1)
                                Text(e.timeText).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if e.start <= .now && e.end > .now && !e.isAllDay {
                                Text("Now")
                                    .font(.caption2.weight(.bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .glassEffect(.regular.tint(e.color), in: .capsule)
                            }
                        }
                        .padding(10)
                        .glassEffect(.regular.tint(e.color.opacity(0.08)).interactive(), in: .rect(cornerRadius: 16))
                        .onTapGesture { model.open(e) }
                    }
                }
            }
        }
    }

    private var remindersCard: some View {
        let items = model.reminders.filter { ($0.isOverdue || $0.isDueToday) && $0.title.matches(model.search) }
        return GlassCard(title: "Due", symbol: AppSection.reminders.symbol, tint: AppSection.reminders.tint,
                         subtitle: items.isEmpty ? nil : "\(items.filter(\.isOverdue).count) overdue",
                         action: { model.section = .reminders }) {
            if model.remindersState == .needsPermission {
                hint("Allow Reminders access in Settings", symbol: "lock")
            } else if items.isEmpty {
                hint("All clear", symbol: "checkmark.seal")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.prefix(6)) { r in ReminderRow(reminder: r, compact: true) }
                }
            }
        }
    }

    private var mailCard: some View {
        let items = model.mail.filter { !$0.isRead && ($0.subject.matches(model.search) || $0.sender.matches(model.search)) }
        let recent = items.isEmpty ? Array(model.mail.prefix(4)) : Array(items.prefix(5))
        return GlassCard(title: items.isEmpty ? "Recent mail" : "Unread mail", symbol: AppSection.mail.symbol,
                         tint: AppSection.mail.tint, subtitle: items.isEmpty ? "Inbox zero" : "\(items.count) unread",
                         action: { model.section = .mail }) {
            if model.mailState == .needsPermission {
                hint("Needs Full Disk Access", symbol: "lock")
            } else if recent.isEmpty {
                hint("No mail", symbol: "tray")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recent) { m in
                        HStack(spacing: 12) {
                            Avatar(name: m.sender, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.sender).font(.subheadline.weight(m.isRead ? .regular : .semibold)).lineLimit(1)
                                Text(m.subject).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(m.date.shortStamp).font(.caption2).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                        .onTapGesture { model.selectedMail = m.id; model.section = .mail }
                    }
                }
            }
        }
    }

    private var messagesCard: some View {
        let items = model.conversations.filter { $0.title.matches(model.search) || $0.lastText.matches(model.search) }
        return GlassCard(title: "Messages", symbol: AppSection.messages.symbol, tint: AppSection.messages.tint,
                         subtitle: model.unreadMessages > 0 ? "\(model.unreadMessages) unread" : nil,
                         action: { model.section = .messages }) {
            if model.messagesState == .needsPermission {
                hint("Needs Full Disk Access", symbol: "lock")
            } else if items.isEmpty {
                hint("No recent conversations", symbol: "bubble.left.and.bubble.right")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.prefix(5)) { c in
                        HStack(spacing: 12) {
                            Avatar(name: c.title, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.title).font(.subheadline.weight(c.unread > 0 ? .semibold : .regular)).lineLimit(1)
                                Text(c.lastText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if c.unread > 0 { Circle().fill(AppSection.messages.tint).frame(width: 8, height: 8) }
                            Text(c.lastDate.shortStamp).font(.caption2).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                        .onTapGesture { model.selectedChat = c.id; model.section = .messages }
                    }
                }
            }
        }
    }

    private func hint(_ text: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }
}
