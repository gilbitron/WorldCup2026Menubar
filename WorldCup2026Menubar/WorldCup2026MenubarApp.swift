import AppKit
import SwiftUI
import UserNotifications

@main
struct WorldCup2026MenubarApp: App {
    @StateObject private var store = ScoreboardStore.shared

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        UserDefaults.standard.register(defaults: [
            SettingsKeys.scoreDisplayMode: ScoreDisplayMode.menuBar.rawValue,
            SettingsKeys.notifyGameStart: true,
            SettingsKeys.notifyGameEnd: true,
            SettingsKeys.notifyGoals: true
        ])

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            MenuBarLabel(title: store.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .monospacedDigit()
    }
}
