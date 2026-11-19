import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.section) {
                ForEach(AppSection.allCases) { s in
                    Label {
                        Text(s.title)
                    } icon: {
                        Image(systemName: s.symbol)
                            .foregroundStyle(s.tint.gradient)
                    }
                    .badge(model.count(for: s))
                    .tag(s)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } detail: {
            ZStack {
                Backdrop(tint: model.section.tint)
                Group {
                    switch model.section {
                    case .today: TodayView()
                    case .mail: MailView()
                    case .messages: MessagesView()
                    case .calendar: CalendarView()
                    case .reminders: RemindersView()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
            .overlay(alignment: .bottom) {
                if let b = model.banner {
                    Label(b.text, systemImage: b.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .glassEffect(.regular.tint((b.isError ? Color.red : Color.green).opacity(0.25)), in: .capsule)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 520)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { model.banner = nil }
                }
            }
            .animation(.smooth(duration: 0.35), value: model.section)
            .navigationTitle(model.section.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh (⌘R)")
                }
            }
            .searchable(text: $model.search, placement: .toolbar, prompt: "Search")
        }
        .task { await model.refresh() }
        .onChange(of: phase) { _, p in
            if p == .active { Task { await model.refresh() } }
        }
    }
}

/// A slowly drifting, colourful mesh gradient so the glass above it has rich colour to refract.
/// The current section's colour leads the palette.
struct Backdrop: View {
    var tint: Color
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate / 9
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [Float(0.5 + 0.18 * sin(t)), Float(0.5 + 0.16 * cos(t * 1.3))], [1, 0.5],
                    [0, 1], [Float(0.5 + 0.2 * cos(t * 0.8)), 1], [1, 1],
                ],
                colors: palette)
        }
        .overlay {
            // Soft light blobs give the glass highlights something to catch.
            GeometryReader { geo in
                Circle().fill(.white.opacity(scheme == .dark ? 0.06 : 0.35))
                    .frame(width: geo.size.width * 0.5)
                    .blur(radius: 90)
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.15)
            }
        }
        .animation(.smooth(duration: 0.8), value: tint)
        .ignoresSafeArea()
    }

    private var palette: [Color] {
        if scheme == .dark {
            return [
                tint.mix(with: .black, by: 0.55), .indigo.mix(with: .black, by: 0.6), .purple.mix(with: .black, by: 0.65),
                .blue.mix(with: .black, by: 0.6), tint.mix(with: .black, by: 0.35), .pink.mix(with: .black, by: 0.6),
                .teal.mix(with: .black, by: 0.65), .indigo.mix(with: .black, by: 0.5), tint.mix(with: .black, by: 0.6),
            ]
        }
        return [
            tint.mix(with: .white, by: 0.55), .cyan.mix(with: .white, by: 0.55), .purple.mix(with: .white, by: 0.6),
            .pink.mix(with: .white, by: 0.6), tint.mix(with: .white, by: 0.35), .blue.mix(with: .white, by: 0.55),
            .orange.mix(with: .white, by: 0.65), .indigo.mix(with: .white, by: 0.55), tint.mix(with: .white, by: 0.5),
        ]
    }
}
