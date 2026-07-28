import SwiftUI
import MooveKit

public struct SoundRow: View {
    let name: String
    let duration: String
    let isSelected: Bool
    let isPlaying: Bool
    let playAction: () -> Void

    public init(name: String, duration: String, isSelected: Bool, isPlaying: Bool, playAction: @escaping () -> Void) {
        self.name = name
        self.duration = duration
        self.isSelected = isSelected
        self.isPlaying = isPlaying
        self.playAction = playAction
    }

    public var body: some View {
        HStack(spacing: MooveSpacing.md) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "music.note")
                .font(MooveFont.title3())
                .foregroundStyle(isSelected ? Color.terracotta : Color.taupe)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                Text(name)
                    .font(MooveFont.body())
                    .foregroundStyle(Color.espresso)
                Text(duration)
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe)
            }

            Spacer()

            Button(action: playAction) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(MooveFont.title2())
                    .foregroundStyle(Color.espresso)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(MooveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MooveCornerRadius.md)
                .stroke(isSelected ? Color.terracotta.opacity(0.4) : Color.hairline, lineWidth: 1.5)
        )
        .background(isSelected ? Color.terracotta.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: MooveCornerRadius.md))
    }
}
