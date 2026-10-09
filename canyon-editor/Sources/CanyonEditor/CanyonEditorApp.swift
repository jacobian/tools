import AppKit
import SwiftUI

@main
struct CanyonEditorApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            // Nothing here makes a new window or a new document.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Where the database is. `just edit` sets CANYON_DB; otherwise the last choice
/// is remembered, and failing that you're asked once.
enum DatabaseLocation {
    private static let defaultsKey = "databasePath"

    static func remembered() -> String? {
        if let env = ProcessInfo.processInfo.environment["CANYON_DB"], !env.isEmpty {
            return env
        }
        guard let saved = UserDefaults.standard.string(forKey: defaultsKey),
              FileManager.default.fileExists(atPath: saved)
        else { return nil }
        return saved
    }

    static func remember(_ path: String) {
        UserDefaults.standard.set(path, forKey: defaultsKey)
    }
}

struct RootView: View {
    @State private var store: Store?
    @State private var openError: String?

    var body: some View {
        Group {
            if let store {
                EditorView(store: store)
            } else {
                ChooseDatabaseView(error: openError, choose: open)
            }
        }
        .onAppear {
            // Launched from a terminal, the app otherwise opens behind iTerm.
            NSApplication.shared.activate(ignoringOtherApps: true)
            if store == nil, let path = DatabaseLocation.remembered() { open(path) }
        }
    }

    private func open(_ path: String) {
        do {
            store = try Store(path: path)
            openError = nil
            DatabaseLocation.remember(path)
        } catch {
            store = nil
            openError = error.localizedDescription
        }
    }
}

struct ChooseDatabaseView: View {
    let error: String?
    let choose: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Open data/canyons.db")
            if let error {
                Text(error).foregroundStyle(.red)
            }
            Button("Choose…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = []
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    choose(url.path)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EditorView: View {
    @Bindable var store: Store
    @State private var tab = Tab.descents

    enum Tab: String, CaseIterable, Identifiable {
        case descents = "Descents"
        case canyons = "Canyons"
        case events = "Events"

        var id: Self { self }
    }

    var body: some View {
        // All three panes stay alive so a half-finished edit survives a switch
        // between tables; only the current one is visible and reachable.
        ZStack {
            pane(.descents) { DescentsPane(store: store) }
            pane(.canyons) { CanyonsPane(store: store) }
            pane(.events) { EventsPane(store: store) }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Table", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        .navigationTitle("Canyon Log")
        .navigationSubtitle(URL(fileURLWithPath: store.path).lastPathComponent)
        .alert(
            "Database error",
            isPresented: Binding(get: { store.errorMessage != nil },
                                 set: { if !$0 { store.errorMessage = nil } })
        ) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func pane(_ which: Tab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(tab == which ? 1 : 0)
            .disabled(tab != which)
            .allowsHitTesting(tab == which)
    }
}
