import SwiftUI

#if canImport(DynamicNotchKit)
import DynamicNotchKit
#endif

@MainActor
final class NotchScorePresenter {
    #if canImport(DynamicNotchKit)
    private var notch: DynamicNotch<NotchScoreView, EmptyView, EmptyView>?
    private var presentedGameID: String?
    #endif

    func update(with game: WorldCupGame?, enabled: Bool) {
        #if canImport(DynamicNotchKit)
        guard enabled, let game else {
            hide()
            return
        }

        guard presentedGameID != game.id else { return }

        presentedGameID = game.id
        let notch = DynamicNotch {
            NotchScoreView(game: game)
        }
        self.notch = notch

        Task {
            await notch.expand()
        }
        #else
        _ = game
        _ = enabled
        #endif
    }

    private func hide() {
        #if canImport(DynamicNotchKit)
        guard let notch else { return }

        self.notch = nil
        presentedGameID = nil

        Task {
            await notch.hide()
        }
        #endif
    }
}

struct NotchScoreView: View {
    let game: WorldCupGame

    var body: some View {
        VStack(spacing: 8) {
            Text(game.statusLabel)
                .font(.caption)
                .foregroundStyle(.red)

            Text(game.compactScoreText)
                .font(.title3.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(game.matchupText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
