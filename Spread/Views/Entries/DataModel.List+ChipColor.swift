import SwiftUI

private let chipColorPalette: [Color] = [
    .blue, .purple, .green, .orange, .red, .pink, .teal, .indigo
]

private func derivedChipColor(id: UUID) -> Color {
    let bytes = withUnsafeBytes(of: id) { Array($0) }
    let hash = bytes.reduce(0) { ($0 &* 31) &+ Int($1) }
    return chipColorPalette[abs(hash) % chipColorPalette.count]
}

extension DataModel.List {
    /// A deterministic color derived from the list's UUID, consistent across sessions.
    var chipColor: Color { derivedChipColor(id: id) }
}

extension DataModel.Tag {
    /// A deterministic color derived from the tag's UUID, consistent across sessions.
    var chipColor: Color { derivedChipColor(id: id) }
}
