import Combine
import Foundation
import UserNotifications

@MainActor
final class ScoreboardStore: ObservableObject {
    static let shared = ScoreboardStore()

    @Published private(set) var games: [WorldCupGame] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let client: ESPNScoreboardClient
    private var pollingTask: Task<Void, Never>?
    private var didHydrateSnapshot = false
    private var previousSnapshots: [String: GameSnapshot] = [:]
    private let notchPresenter = NotchScorePresenter()

    var liveGames: [WorldCupGame] {
        games.filter(\.isLive)
    }

    var nextUpcomingGame: WorldCupGame? {
        let now = Date()
        return games.first { $0.startDate >= now && !$0.isCompleted }
    }

    var displayedGames: [WorldCupGame] {
        let now = Date()
        let startDate = now.addingTimeInterval(-24 * 60 * 60)
        let endDate = now.addingTimeInterval(24 * 60 * 60)
        let nearbyGames = games.filter { startDate...endDate ~= $0.startDate }

        if !nearbyGames.isEmpty {
            return nearbyGames
        }

        return games.filter { $0.startDate >= now && !$0.isCompleted }.prefix(5).map(\.self)
    }

    var listTitle: String {
        let now = Date()
        let startDate = now.addingTimeInterval(-24 * 60 * 60)
        let endDate = now.addingTimeInterval(24 * 60 * 60)
        let hasNearbyGames = displayedGames.contains { startDate...endDate ~= $0.startDate }
        return hasNearbyGames ? "Recent and upcoming" : "Next matches"
    }

    var menuBarTitle: String {
        if let liveGame = liveGames.first {
            return liveGame.compactScoreText
        }

        guard let nextGame = nextUpcomingGame else {
            return "World Cup"
        }

        return nextGame.menuBarUpcomingText
    }

    var lastUpdatedText: String {
        guard let lastUpdated else {
            return "Not updated yet"
        }

        return "Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))"
    }

    init(client: ESPNScoreboardClient = ESPNScoreboardClient()) {
        self.client = client
        startPolling()
    }

    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let hasLiveGame = self?.liveGames.isEmpty == false
                let delay: UInt64 = hasLiveGame ? 30_000_000_000 : 300_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedGames = try await client.fetchGames()
            processNotifications(for: fetchedGames)
            games = fetchedGames
            lastUpdated = .now
            errorMessage = nil
            updateLivePresentation()
        } catch {
            errorMessage = "Could not load ESPN scores: \(Self.errorDescription(for: error))"
        }
    }

    func updateLivePresentation() {
        let shouldUseNotch = UserDefaults.standard.string(forKey: SettingsKeys.scoreDisplayMode) == ScoreDisplayMode.dynamicNotch.rawValue
        notchPresenter.update(with: liveGames.first, enabled: shouldUseNotch)
    }

    private func processNotifications(for fetchedGames: [WorldCupGame]) {
        let newSnapshots = Dictionary(uniqueKeysWithValues: fetchedGames.map { ($0.id, GameSnapshot(game: $0)) })

        defer {
            previousSnapshots = newSnapshots
            didHydrateSnapshot = true
        }

        guard didHydrateSnapshot else { return }

        for game in fetchedGames {
            guard let previous = previousSnapshots[game.id] else { continue }

            if UserDefaults.standard.bool(forKey: SettingsKeys.notifyGameStart),
               previous.statusState == .scheduled,
               game.status.state == .live {
                sendNotification(title: "Kickoff", body: "\(game.matchupText) has started.")
            }

            if UserDefaults.standard.bool(forKey: SettingsKeys.notifyGameEnd),
               previous.statusState != .completed,
               game.status.state == .completed {
                sendNotification(title: "Full time", body: "\(game.matchupText) finished \(game.scoreText).")
            }

            if UserDefaults.standard.bool(forKey: SettingsKeys.notifyGoals),
               game.goalCount > previous.goalCount || game.totalScore > previous.totalScore {
                sendNotification(title: "Goal", body: "\(game.matchupText): \(game.scoreText)")
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func errorDescription(for error: Error) -> String {
        if let urlError = error as? URLError {
            return "\(urlError.localizedDescription) (\(urlError.code.rawValue), \(urlError.code))"
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .dataCorrupted(let context):
                return context.debugDescription
            case .keyNotFound(let key, let context):
                return "Missing field '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))."
            case .typeMismatch(_, let context), .valueNotFound(_, let context):
                return context.debugDescription
            @unknown default:
                return decodingError.localizedDescription
            }
        }

        return error.localizedDescription
    }
}

private struct GameSnapshot {
    let statusState: GameStatus.State
    let goalCount: Int
    let totalScore: Int

    init(game: WorldCupGame) {
        statusState = game.status.state
        goalCount = game.goalCount
        totalScore = game.totalScore
    }
}

extension ScoreboardStore {
    static let preview: ScoreboardStore = {
        let store = ScoreboardStore(client: ESPNScoreboardClient())
        store.pollingTask?.cancel()
        store.games = [
            WorldCupGame(
                id: "preview-live",
                startDate: .now,
                homeTeam: TeamScore(name: "Mexico", abbreviation: "MEX", score: 2, isWinner: false),
                awayTeam: TeamScore(name: "South Africa", abbreviation: "RSA", score: 0, isWinner: false),
                status: .live(clock: "67'"),
                goalCount: 2,
                venue: "Estadio Banorte"
            )
        ]
        store.lastUpdated = .now
        return store
    }()
}
