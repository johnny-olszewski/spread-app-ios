import struct Foundation.Calendar
import struct Foundation.Date

/// Validation errors for spread creation.
enum SpreadCreationError: Equatable {
    /// The selected date is in the past.
    case pastDate

    /// A spread already exists for this period/date.
    case duplicate

    /// The multiday date range is invalid (end before start).
    case invalidRange

    /// User-facing error message.
    var message: String {
        switch self {
        case .pastDate:
            return "You can only create spreads for present or future dates"
        case .duplicate:
            return "A spread for this time period already exists"
        case .invalidRange:
            return "End date must be after start date"
        }
    }
}

/// Result of spread creation validation.
struct SpreadCreationResult {
    /// Whether creation is allowed.
    let isValid: Bool

    /// The error if creation is not allowed.
    let error: SpreadCreationError?

    /// Creates a valid result.
    static var valid: SpreadCreationResult {
        SpreadCreationResult(isValid: true, error: nil)
    }

    /// Creates an invalid result with the given error.
    static func invalid(_ error: SpreadCreationError) -> SpreadCreationResult {
        SpreadCreationResult(isValid: false, error: error)
    }
}

/// Configuration and validation logic for spread creation.
///
/// Encapsulates the business rules for creating spreads, including:
/// - Date validation (present/future only, multiday exceptions)
/// - Duplicate detection
/// - Preset date range calculations
struct SpreadCreationConfiguration {

    // MARK: - Properties

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The reference date (typically today).
    let today: Date

    /// The user's first day of week preference.
    let firstWeekday: FirstWeekday

    /// Existing spreads for duplicate detection.
    let existingSpreads: [DataModel.Spread]

    /// The creation policy for validation.
    private var creationPolicy: StandardCreationPolicy {
        StandardCreationPolicy(today: today, firstWeekday: firstWeekday)
    }

    // MARK: - Period Descriptions

    /// Returns a description for the given period.
    static func periodDescription(for period: Period) -> String {
        switch period {
        case .year:
            return "A year spread covers all 12 months"
        case .month:
            return "A month spread covers all days in that month"
        case .day:
            return "A day spread covers a single day"
        case .multiday:
            return "A multiday spread covers a custom date range"
        }
    }

    // MARK: - Validation

    /// Validates whether a spread can be created for the given period and date.
    ///
    /// - Parameters:
    ///   - period: The period for the spread.
    ///   - date: The date for the spread.
    /// - Returns: A result indicating whether creation is valid.
    func canCreate(period: Period, date: Date) -> SpreadCreationResult {
        // Check for duplicates first
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let spreadExists = existingSpreads.contains { spread in
            spread.period == period &&
            period.normalizeDate(spread.date, calendar: calendar) == normalizedDate
        }

        if spreadExists {
            return .invalid(.duplicate)
        }

        // Check date validity
        let canCreate = creationPolicy.canCreateSpread(
            period: period,
            date: date,
            spreadExists: false,
            calendar: calendar
        )

        if !canCreate {
            return .invalid(.pastDate)
        }

        return .valid
    }

    /// Validates whether a multiday spread can be created for the given date range.
    ///
    /// - Parameters:
    ///   - startDate: The start date of the range.
    ///   - endDate: The end date of the range.
    /// - Returns: A result indicating whether creation is valid.
    func canCreateMultiday(startDate: Date, endDate: Date) -> SpreadCreationResult {
        let normalizedStart = startDate.startOfDay(calendar: calendar)
        let normalizedEnd = endDate.startOfDay(calendar: calendar)

        // Check range validity
        if normalizedEnd < normalizedStart {
            return .invalid(.invalidRange)
        }

        // Check for duplicates
        let spreadExists = existingSpreads.contains { spread in
            guard spread.period == .multiday,
                  let existingStart = spread.startDate,
                  let existingEnd = spread.endDate else {
                return false
            }
            return existingStart.startOfDay(calendar: calendar) == normalizedStart &&
                   existingEnd.startOfDay(calendar: calendar) == normalizedEnd
        }

        if spreadExists {
            return .invalid(.duplicate)
        }

        // Check date validity
        let canCreate = creationPolicy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        if !canCreate {
            return .invalid(.pastDate)
        }

        return .valid
    }

    // MARK: - Date Ranges

    /// Returns the date range for a multiday preset.
    ///
    /// - Parameter preset: The preset to calculate.
    /// - Returns: The start and end dates, or `nil` if calculation fails.
    func dateRange(for preset: MultidayPreset) -> (startDate: Date, endDate: Date)? {
        preset.dateRange(from: today, calendar: calendar, firstWeekday: firstWeekday)
    }

    /// Returns the minimum selectable date for a given period.
    ///
    /// For year/month/day, this is the normalized start of the current period.
    /// - Parameter period: The period to calculate for.
    /// - Returns: The minimum selectable date.
    func minimumDate(for period: Period) -> Date {
        period.normalizeDate(today, calendar: calendar)
    }

    /// Returns the maximum selectable date (10 years in the future).
    var maximumDate: Date {
        calendar.date(byAdding: .year, value: 10, to: today) ?? today
    }

    /// Returns the minimum start date for multiday spreads.
    ///
    /// This is the first day of the current week (allowing past dates within the week).
    var minimumMultidayStartDate: Date {
        today.firstDayOfWeek(calendar: calendar, firstWeekday: firstWeekday) ?? today
    }

    /// Returns the minimum end date for multiday spreads (today).
    var minimumMultidayEndDate: Date {
        today.startOfDay(calendar: calendar)
    }
}
