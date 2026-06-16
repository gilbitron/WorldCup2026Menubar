import Foundation

struct WorldCupGame: Identifiable, Equatable {
    let id: String
    let startDate: Date
    let homeTeam: TeamScore
    let awayTeam: TeamScore
    let status: GameStatus
    let goalCount: Int
    let venue: String?

    var isLive: Bool {
        status.state == .live
    }

    var isCompleted: Bool {
        status.state == .completed
    }

    var totalScore: Int {
        homeTeam.score + awayTeam.score
    }

    var scoreText: String {
        "\(homeTeam.abbreviation) \(homeTeam.score)-\(awayTeam.score) \(awayTeam.abbreviation)"
    }

    var compactScoreText: String {
        "\(homeTeam.abbreviation) \(homeTeam.score)-\(awayTeam.score) \(awayTeam.abbreviation)"
    }

    var matchupText: String {
        "\(homeTeam.name) vs \(awayTeam.name)"
    }

    var menuBarUpcomingText: String {
        "\(homeTeam.abbreviation) vs \(awayTeam.abbreviation) \(menuBarStartTimeText)"
    }

    var rowLocationLabel: String {
        venue ?? "Venue TBA"
    }

    var rowStatusText: String {
        switch status {
        case .scheduled:
            startTimeText
        case .live(let clock):
            clock.isEmpty ? "Live" : clock
        case .completed(let detail):
            detail
        }
    }

    var statusLabel: String {
        switch status {
        case .scheduled:
            "Scheduled"
        case .live(let clock):
            clock.isEmpty ? "Live" : clock
        case .completed(let detail):
            detail
        }
    }

    var startTimeText: String {
        startDate.formatted(date: .omitted, time: .shortened)
    }

    private var menuBarStartTimeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: startDate).replacingOccurrences(of: ":00", with: "")
    }
}

struct TeamScore: Equatable {
    let name: String
    let abbreviation: String
    let score: Int
    let isWinner: Bool
}

enum GameStatus: Equatable {
    case scheduled(detail: String)
    case live(clock: String)
    case completed(detail: String)

    enum State {
        case scheduled
        case live
        case completed
    }

    var state: State {
        switch self {
        case .scheduled:
            .scheduled
        case .live:
            .live
        case .completed:
            .completed
        }
    }
}

enum ScoreDisplayMode: String {
    case menuBar
    case dynamicNotch
}

enum SettingsKeys {
    static let scoreDisplayMode = "scoreDisplayMode"
    static let notifyGameStart = "notifyGameStart"
    static let notifyGameEnd = "notifyGameEnd"
    static let notifyGoals = "notifyGoals"
}
