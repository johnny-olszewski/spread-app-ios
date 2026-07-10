import Foundation

/// Drives create-vs-edit chrome differences inside `EntrySheet`.
///
/// - `.create`: Shows a hidden-until-edited primary button labeled "Create", enables
///   auto-focus, and engages `interactiveDismissDisabled` once the primary button is visible.
/// - `.edit`: Shows a "Save" button and optional delete/history/lifecycle sections.
enum EntrySheetMode {
    case create
    case edit
}
