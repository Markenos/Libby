import SwiftUI

@main
struct LibbyApp: App {
    @State private var model = AppModel()

    init() {
        if CommandLine.arguments.contains("--selftest") { SelfTest.run() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh") { Task { await model.refresh() } }
                    .keyboardShortcut("r")
                Divider()
                ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { i, s in
                    Button(s.title) { model.section = s }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")))
                }
            }
        }
    }
}
