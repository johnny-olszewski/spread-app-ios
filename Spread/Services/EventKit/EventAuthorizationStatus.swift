import EventKit

/// Authorization status for EventKit calendar access.
enum EventAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .fullAccess:
            self = .authorized
        case .writeOnly, .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .denied
        }
    }
}
