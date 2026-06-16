import Foundation

struct ESPNScoreboardClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    nonisolated init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeESPNDate)
        self.decoder = decoder
    }

    func fetchGames(from startDate: Date = .now, days: Int = 14) async throws -> [WorldCupGame] {
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate
        var components = URLComponents(string: "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "dates", value: "\(Self.espnDate(startDate))-\(Self.espnDate(endDate))")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw ESPNScoreboardError.httpStatus(httpResponse.statusCode)
        }

        let scoreboard = try decoder.decode(ESPNScoreboardResponse.self, from: data)
        return scoreboard.events.compactMap(WorldCupGame.init(response:)).sorted { $0.startDate < $1.startDate }
    }

    nonisolated private static func decodeESPNDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let date = ISO8601DateFormatter.espnInternetDateTime.date(from: value) {
            return date
        }

        if let date = DateFormatter.espnUTCDateTimeWithoutSeconds.date(from: value) {
            return date
        }

        if let date = DateFormatter.espnUTCDateTimeWithSeconds.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported ESPN date format: \(value)"
        )
    }

    private static func espnDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

enum ESPNScoreboardError: LocalizedError {
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let statusCode):
            "ESPN returned HTTP \(statusCode)."
        }
    }
}

nonisolated private extension DateFormatter {
    static let espnUTCDateTimeWithoutSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        return formatter
    }()

    static let espnUTCDateTimeWithSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }()
}

nonisolated private extension ISO8601DateFormatter {
    static let espnInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct ESPNScoreboardResponse: Decodable {
    let events: [ESPNEvent]
}

private struct ESPNEvent: Decodable {
    let id: String
    let date: Date
    let competitions: [ESPNCompetition]
}

private struct ESPNCompetition: Decodable {
    let status: ESPNStatus
    let competitors: [ESPNCompetitor]
    let details: [ESPNDetail]?
    let venue: ESPNVenue?
}

private struct ESPNStatus: Decodable {
    let displayClock: String?
    let type: ESPNStatusType
}

private struct ESPNStatusType: Decodable {
    let state: String
    let completed: Bool?
    let detail: String?
    let shortDetail: String?
}

private struct ESPNCompetitor: Decodable {
    let homeAway: String
    let score: String?
    let winner: Bool?
    let team: ESPNTeam
}

private struct ESPNTeam: Decodable {
    let abbreviation: String?
    let displayName: String
    let shortDisplayName: String?
}

private struct ESPNDetail: Decodable {
    let scoringPlay: Bool?
}

private struct ESPNVenue: Decodable {
    let fullName: String?
    let displayName: String?
}

extension WorldCupGame {
    fileprivate init?(response event: ESPNEvent) {
        guard let competition = event.competitions.first,
              let home = competition.competitors.first(where: { $0.homeAway == "home" }),
              let away = competition.competitors.first(where: { $0.homeAway == "away" }) else {
            return nil
        }

        self.init(
            id: event.id,
            startDate: event.date,
            homeTeam: TeamScore(response: home),
            awayTeam: TeamScore(response: away),
            status: GameStatus(response: competition.status),
            goalCount: competition.details?.filter { $0.scoringPlay == true }.count ?? 0,
            venue: competition.venue?.fullName ?? competition.venue?.displayName
        )
    }
}

extension TeamScore {
    fileprivate init(response competitor: ESPNCompetitor) {
        self.init(
            name: competitor.team.shortDisplayName ?? competitor.team.displayName,
            abbreviation: competitor.team.abbreviation ?? competitor.team.displayName,
            score: Int(competitor.score ?? "") ?? 0,
            isWinner: competitor.winner == true
        )
    }
}

extension GameStatus {
    fileprivate init(response status: ESPNStatus) {
        switch status.type.state {
        case "in":
            self = .live(clock: status.displayClock ?? status.type.shortDetail ?? "Live")
        case "post":
            self = .completed(detail: status.type.shortDetail ?? status.type.detail ?? "FT")
        default:
            self = .scheduled(detail: status.type.shortDetail ?? status.type.detail ?? "Scheduled")
        }
    }
}
