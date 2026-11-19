import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.section) {
                ForEach(AppSection.allCases) { s in
                    Label(s.title, systemImage: s.symbol)
                        .badge(model.count(for: s))
                        .tag(s)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            ZStack {
                Backdrop()
                Group {
                    switch model.section {
                    case .today: TodayView()
                    case .mail: MailView()
                    case .messages: MessagesView()
                    case .calendar: CalendarView()
                    case .reminders: RemindersView()
                    }
                }
                .transition(.opacity)
            }
            .animation(.smooth(duration: 0.25), value: model.section)
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

/// A quiet, barely-there wash behind content so the glass has something to refract.
struct Backdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(white: 0.09), Color(red: 0.08, green: 0.09, blue: 0.13)]
                : [Color(white: 0.97), Color(red: 0.93, green: 0.95, blue: 0.99)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.accentColor.opacity(scheme == .dark ? 0.18 : 0.12))
                    .frame(width: 520, height: 520)
                    .blur(radius: 120)
                    .offset(x: 160, y: -220)
            }
            .ignoresSafeArea()
    }
}
