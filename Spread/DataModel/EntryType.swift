/// The type of entry in the journal.
///
/// Each entry type has a distinct symbol and display name used in the UI.
enum EntryType: String, CaseIterable, Codable, Sendable {
    case task
    case event
    case note

    /// The SF Symbol name for this entry type.
    ///
    /// - Task: solid circle (●)
    /// - Event: empty circle (○)
    /// - Note: dash (—)
    var imageName: String {
        switch self {
        case .task: "circle.fill"
        case .event: "circle"
        case .note: "minus"
        }
    }

    /// The human-readable display name for this entry type.
    var displayName: String {
        switch self {
        case .task: "Task"
        case .event: "Event"
        case .note: "Note"
        }
    }
}
