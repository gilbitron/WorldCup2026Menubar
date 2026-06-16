import SwiftUI
import UserNotifications

struct ContentView: View {
    @ObservedObject var store: ScoreboardStore
    @State private var selectedScreen = PopoverScreen.scores
    @AppStorage(SettingsKeys.scoreDisplayMode) private var scoreDisplayMode = ScoreDisplayMode.menuBar.rawValue
    @AppStorage(SettingsKeys.notifyGameStart) private var notifyGameStart = true
    @AppStorage(SettingsKeys.notifyGameEnd) private var notifyGameEnd = true
    @AppStorage(SettingsKeys.notifyGoals) private var notifyGoals = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            switch selectedScreen {
            case .scores:
                games
            case .settings:
                SettingsView(
                    scoreDisplayMode: $scoreDisplayMode,
                    notifyGameStart: $notifyGameStart,
                    notifyGameEnd: $notifyGameEnd,
                    notifyGoals: $notifyGoals,
                    onNotificationToggle: requestNotificationsIfNeeded,
                    onDisplayModeChange: store.updateLivePresentation
                )
            }

            if selectedScreen == .scores {
                Divider()

                footer
            }
        }
        .frame(width: 360)
        .padding(14)
        .task {
            await store.refresh()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(headerTitle)
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                switch selectedScreen {
                case .scores:
                    Task {
                        await store.refresh()
                    }
                case .settings:
                    selectedScreen = .scores
                }
            } label: {
                Image(systemName: selectedScreen == .scores ? refreshIconName : "checkmark")
            }
            .buttonStyle(.borderless)
            .help(selectedScreen == .scores ? "Refresh" : "Done")
            .disabled(selectedScreen == .scores && store.isLoading)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()

            Button {
                selectedScreen = .settings
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .disabled(selectedScreen == .settings)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit World Cup 2026 Menubar")
        }
    }

    private var headerTitle: String {
        switch selectedScreen {
        case .scores:
            store.listTitle
        case .settings:
            "Settings"
        }
    }

    private var headerSubtitle: String {
        switch selectedScreen {
        case .scores:
            store.lastUpdatedText
        case .settings:
            "Scores, notch, and notifications"
        }
    }

    private var refreshIconName: String {
        store.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
    }

    @ViewBuilder
    private var games: some View {
        if let errorMessage = store.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label("ESPN request failed", systemImage: "exclamationmark.triangle")
                    .font(.callout.weight(.medium))

                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        } else if store.displayedGames.isEmpty {
            ContentUnavailableView("No matches found", systemImage: "calendar.badge.exclamationmark")
                .frame(height: 120)
        } else {
            VStack(spacing: 0) {
                ForEach(store.displayedGames) { game in
                    GameRow(game: game)

                    if game.id != store.displayedGames.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func requestNotificationsIfNeeded(_ enabled: Bool) {
        guard enabled else { return }

        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }
}

private enum PopoverScreen {
    case scores
    case settings
}

private struct SettingsView: View {
    @Binding var scoreDisplayMode: String
    @Binding var notifyGameStart: Bool
    @Binding var notifyGameEnd: Bool
    @Binding var notifyGoals: Bool

    let onNotificationToggle: (Bool) -> Void
    let onDisplayModeChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live score display")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Live score display", selection: $scoreDisplayMode) {
                    Text("Menu bar").tag(ScoreDisplayMode.menuBar.rawValue)
                    Text("Dynamic Notch").tag(ScoreDisplayMode.dynamicNotch.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Notifications")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Game start", isOn: $notifyGameStart)
                Toggle("Full time", isOn: $notifyGameEnd)
                Toggle("Goals", isOn: $notifyGoals)
            }
        }
        .padding(.vertical, 6)
        .onChange(of: notifyGameStart) { _, newValue in onNotificationToggle(newValue) }
        .onChange(of: notifyGameEnd) { _, newValue in onNotificationToggle(newValue) }
        .onChange(of: notifyGoals) { _, newValue in onNotificationToggle(newValue) }
        .onChange(of: scoreDisplayMode) { _, _ in onDisplayModeChange() }
    }
}

private struct GameRow: View {
    let game: WorldCupGame

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(game.rowLocationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(game.rowStatusText)
                    .font(.caption)
                    .foregroundStyle(game.isLive ? .red : .secondary)
                    .lineLimit(1)
            }

            teamRow(game.homeTeam, isWinner: game.homeTeam.isWinner)
            teamRow(game.awayTeam, isWinner: game.awayTeam.isWinner)
        }
        .padding(.vertical, 10)
    }

    private func teamRow(_ team: TeamScore, isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            Text(team.abbreviation)
                .font(.body.monospaced())
                .fontWeight(isWinner ? .semibold : .regular)
                .frame(width: 44, alignment: .leading)

            Text(team.name)
                .lineLimit(1)

            Spacer()

            Text("\(team.score)")
                .font(.body.monospacedDigit())
                .fontWeight(isWinner ? .semibold : .regular)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: ScoreboardStore.preview)
    }
}
