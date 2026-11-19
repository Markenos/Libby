import SwiftUI

struct RemindersView: View {
    @Environment(AppModel.self) private var model

    private var lists: [(String, [ReminderItem])] {
        let filtered = model.reminders.filter { $0.title.matches(model.search) || ($0.notes ?? "").matches(model.search) }
        let grouped = Dictionary(grouping: filtered, by: \.list)
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { ($0, grouped[$0]!) }
    }

    var body: some View {
        SourceGate(state: model.remindersState, permission: AnyView(
            PermissionPanel(symbol: "checklist", title: "Reminders access is off",
                            message: "Allow Libby to see your reminders in Privacy & Security › Reminders.",
                            buttonTitle: "Open Settings",
                            action: { AppModel.openPrivacySettings("Privacy_Reminders") }))) {
            if lists.isEmpty {
                EmptyState(symbol: "checkmark.circle", text: "No reminders")
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(lists, id: \.0) { name, items in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Circle().fill(items.first?.color ?? .accentColor).frame(width: 9, height: 9)
                                        Text(name).font(.headline)
                                        Spacer()
                                        Text("\(items.filter { !$0.isCompleted }.count)")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    ForEach(items) { r in ReminderRow(reminder: r) }
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

struct ReminderRow: View {
    @Environment(AppModel.self) private var model
    let reminder: ReminderItem
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { model.toggle(reminder) } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(reminder.isCompleted ? AnyShapeStyle(reminder.color) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                    .lineLimit(compact ? 1 : 3)
                if let due = reminder.due {
                    Text(dueText(due))
                        .font(.caption)
                        .foregroundStyle(reminder.isOverdue ? Color.red : .secondary)
                } else if compact {
                    Text(reminder.list).font(.caption).foregroundStyle(.secondary)
                }
                if !compact, let notes = reminder.notes {
                    Text(notes).font(.caption).foregroundStyle(.tertiary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func dueText(_ d: Date) -> String {
        let hasTime = Calendar.current.dateComponents([.hour, .minute], from: d) != DateComponents(hour: 0, minute: 0)
        if Calendar.current.isDateInToday(d) {
            return hasTime ? "Today, \(d.formatted(date: .omitted, time: .shortened))" : "Today"
        }
        return hasTime ? d.formatted(date: .abbreviated, time: .shortened) : d.formatted(date: .abbreviated, time: .omitted)
    }
}
