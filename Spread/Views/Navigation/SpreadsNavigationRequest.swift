import Foundation
import Observation

struct SpreadsNavigationRequest: Identifiable {
    let id = UUID()
    let selection: DataModel.Spread
    let taskID: UUID
}

@Observable
@MainActor
final class SpreadsNavigationState {
    var pendingRequest: SpreadsNavigationRequest?
}
