import Foundation

/// Maps between dates and Y-offsets within a fixed-height visible time window.
///
/// Dates outside the visible window are clamped so events that partially
/// extend beyond the window still appear clipped at the edge rather than
/// disappearing entirely.
public struct DayTimeCoordinateSpace: Sendable {

    // MARK: - Properties

    /// The date at the top of the visible window (e.g. 6:00 AM).
    public let visibleStart: Date

    /// The date at the bottom of the visible window (e.g. 10:00 PM).
    public let visibleEnd: Date

    /// Total pixel height of the rendered timeline.
    public let totalHeight: CGFloat

    // MARK: - Init

    public init(visibleStart: Date, visibleEnd: Date, totalHeight: CGFloat) {
        self.visibleStart = visibleStart
        self.visibleEnd = visibleEnd
        self.totalHeight = totalHeight
    }

    // MARK: - Coordinate math

    /// Total duration represented by the visible window in seconds.
    public var totalSeconds: TimeInterval {
        visibleEnd.timeIntervalSince(visibleStart)
    }

    /// Returns the Y-offset for a given date, clamped to `[0, totalHeight]`.
    public func yOffset(for date: Date) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(visibleStart)
        let fraction = elapsed / totalSeconds
        return (fraction * totalHeight).clamped(to: 0...totalHeight)
    }

    /// Returns the pixel height for the portion of a date range that falls within
    /// the visible window. Returns 0 if the range is entirely outside the window.
    public func height(from startDate: Date, to endDate: Date) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        let clampedStart = max(startDate, visibleStart)
        let clampedEnd = min(endDate, visibleEnd)
        guard clampedEnd > clampedStart else { return 0 }
        let fraction = clampedEnd.timeIntervalSince(clampedStart) / totalSeconds
        return fraction * totalHeight
    }
}

// MARK: - CGFloat clamping helper

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
