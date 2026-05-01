import SwiftUI

struct SpreadAutoMigrationCueView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "arrow.triangle.swap")
            .font(SpreadTheme.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(SpreadTheme.Accent.todaySelectedEmphasis)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .circular)
                    .fill(SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.12))
            )
    }
}
