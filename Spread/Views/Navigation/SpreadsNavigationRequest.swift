import Foundation
import Observation

struct SpreadsNavigationRequest: Identifiable {
    let id = UUID()
    let selection: SpreadHeaderNavigatorModel.Selection
    let taskID: UUID
}

@Observable
@MainActor
final class SpreadsNavigationState {
    var pendingRequest: SpreadsNavigationRequest?
}
