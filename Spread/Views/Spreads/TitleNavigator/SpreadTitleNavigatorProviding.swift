import Foundation

/// Provides a mode-aware title navigator model for the spreads strip.
///
/// Conforming types produce a `SpreadTitleNavigatorModel` appropriate for the
/// current BuJo mode, hiding mode branching from the spreads shell.
protocol SpreadTitleNavigatorProviding {
    /// The title navigator model for the current BuJo mode.
    var titleNavigatorModel: SpreadTitleNavigatorModel { get }
}
