import SwiftUI

// MARK: - Glass card

struct GlassCard<Content: View>: View {
    var title: String? = nil
    var symbol: String? = nil
    var tint: Color = .accentColor
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                HStack(spacing: 12) {
                    if let symbol { IconBadge(symbol: symbol, tint: tint) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.headline)
                        if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    if let action {
                        Button(action: action) {
                            Image(systemName: "arrow.up.right").font(.caption.weight(.bold))
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .help("Open \(title)")
                    }
                }
            }
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: .rect(cornerRadius: 30))
    }
}

/// A small coloured glass disc holding an SF Symbol.
struct IconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(tint.opacity(0.85)), in: .circle)
    }
}

/// A big number on tinted glass, used in Today's summary row.
struct StatPill: View {
    let value: Int
    let label: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBadge(symbol: symbol, tint: tint, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(label).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint.opacity(0.16)).interactive(), in: .rect(cornerRadius: 22))
    }
}

// MARK: - Empty & permission states

struct EmptyState: View {
    let symbol: String
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct PermissionPanel: View {
    let symbol: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            Button(buttonTitle, action: action)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .padding(32)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FullDiskAccessPanel: View {
    let source: String
    var body: some View {
        PermissionPanel(
            symbol: "lock",
            title: "Libby needs Full Disk Access",
            message: "To show \(source), turn on Libby in Privacy & Security › Full Disk Access, then reopen Libby. Everything stays on this Mac.",
            buttonTitle: "Open Settings",
            action: AppModel.openFullDiskAccessSettings)
    }
}

/// Switches between loading / permission / failure / content for a source.
struct SourceGate<Content: View>: View {
    let state: SourceState
    let permission: AnyView
    @ViewBuilder var content: Content

    var body: some View {
        switch state {
        case .idle, .loading: ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .needsPermission: permission
        case .failed(let msg): EmptyState(symbol: "exclamationmark.triangle", text: msg)
        case .ready: content
        }
    }
}

// MARK: - Avatar

struct Avatar: View {
    let name: String
    var size: CGFloat = 34

    private var initials: String {
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "," }).prefix(2)
        let s = parts.compactMap { $0.first.map(String.init) }.joined()
        return s.isEmpty || s.first?.isNumber == true || s.first == "+" ? "" : s.uppercased()
    }

    private var tint: Color {
        let palette: [Color] = [.blue, .indigo, .purple, .pink, .orange, .teal, .green, .mint]
        let h = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[h % palette.count]
    }

    var body: some View {
        ZStack {
            Circle().fill(tint.gradient.opacity(0.85))
            if initials.isEmpty {
                Image(systemName: "person.fill").font(.system(size: size * 0.42)).foregroundStyle(.white)
            } else {
                Text(initials).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Formatting

extension Date {
    /// "9:41", "Yesterday", "Tue", "12 Nov"
    var shortStamp: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return formatted(date: .omitted, time: .shortened) }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        if let days = cal.dateComponents([.day], from: self, to: .now).day, days < 7 {
            return formatted(.dateTime.weekday(.abbreviated))
        }
        return formatted(.dateTime.day().month(.abbreviated))
    }

    var dayHeading: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInTomorrow(self) { return "Tomorrow" }
        return formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

extension EventItem {
    var timeText: String {
        if isAllDay { return "All day" }
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }
}

/// List rows: the selected row floats on tinted, interactive glass that morphs between rows.
struct RowBackground: ViewModifier {
    let selected: Bool
    var tint: Color = .accentColor
    var namespace: Namespace.ID? = nil

    func body(content: Content) -> some View {
        let row = content
            .padding(.horizontal, 12).padding(.vertical, 10)
            .contentShape(.rect(cornerRadius: 18))
        if selected {
            if let namespace {
                row.glassEffect(.regular.tint(tint.opacity(0.28)).interactive(), in: .rect(cornerRadius: 18))
                    .glassEffectID("selection", in: namespace)
            } else {
                row.glassEffect(.regular.tint(tint.opacity(0.28)).interactive(), in: .rect(cornerRadius: 18))
            }
        } else {
            row
        }
    }
}

/// A tall glass panel used for the list column in Mail and Messages.
struct GlassPanel<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content
    var body: some View {
        content
            .glassEffect(.regular.tint(tint.opacity(0.06)), in: .rect(cornerRadius: 30))
    }
}
