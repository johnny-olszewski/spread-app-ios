import struct Foundation.UUID

/// Namespace for data model types.
///
/// All SwiftData @Model classes are defined as extensions on this struct
/// to provide clear namespacing (e.g., `DataModel.Task`, `DataModel.Spread`).
enum DataModel {
    // MARK: - Stub Types (TODO: SPRD-4, SPRD-8, SPRD-9, SPRD-39)
    // These placeholder types allow repository protocols to compile.
    // They will be replaced with @Model classes in future tasks.

    /// Placeholder for spread model. Implemented in SPRD-8.
    struct Spread: Identifiable, Hashable, Sendable {
        let id: UUID
    }

    /// Placeholder for task model. Implemented in SPRD-9.
    struct Task: Identifiable, Hashable, Sendable {
        let id: UUID
    }

    /// Placeholder for event model. Implemented in SPRD-9.
    struct Event: Identifiable, Hashable, Sendable {
        let id: UUID
    }

    /// Placeholder for note model. Implemented in SPRD-9.
    struct Note: Identifiable, Hashable, Sendable {
        let id: UUID
    }

    /// Placeholder for collection model. Implemented in SPRD-39.
    struct Collection: Identifiable, Hashable, Sendable {
        let id: UUID
    }
}
