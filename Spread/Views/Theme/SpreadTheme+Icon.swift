import SwiftUI
import PhosphorSwift

/// Semantic icon tokens for the app, backed by the bundled Phosphor icon set.
///
/// Single source of truth for icon choice — mirrors `SpreadTheme.Typography`'s role for fonts.
/// Every icon-producing call site in the app resolves through a `SpreadTheme.Icon` case rather
/// than naming a raw SF Symbol or Phosphor identifier directly. SF Symbol outlines map to
/// Phosphor's `.regular` weight; existing `*.fill` SF Symbols map to Phosphor's `.fill` weight —
/// no other Phosphor weight (`.thin`/`.light`/`.bold`/`.duotone`) is used.
extension SpreadTheme {
    enum Icon: CaseIterable {

        // MARK: - Actions

        case plus
        case minus
        case xmark
        case xmarkCircle
        case xmarkCircleFilled
        case checkmark
        case checkCircle
        case checkCircleFilled
        case trash
        case pencil
        /// Compose/edit action — replaces SF Symbol `square.and.pencil`.
        case editCompose
        case copy
        case link

        // MARK: - Status / Selection

        case circle
        case circleFilled
        case star
        case starFilled
        case tag
        case tagFilled
        case folder
        case folderFilled

        // MARK: - Navigation

        case arrowRight
        case arrowRightCircle
        case arrowRightCircleFilled
        /// Undo/restore action — replaces SF Symbol `arrow.uturn.backward.circle`.
        case arrowUTurnLeft
        case caretDown
        case caretRight
        case caretLeft
        /// Sort/expand indicator — replaces SF Symbol `chevron.up.chevron.down`.
        case arrowsUpDown
        case swap

        // MARK: - Sync

        case arrowsClockwise
        case cloudWarning
        case cloud

        // MARK: - Calendar / Time

        case calendar
        case calendarFilled
        case calendarPlus
        /// Month period icon — replaces SF Symbol `calendar.badge.clock`.
        case calendarDots
        case sun
        case sunFilled
        /// Multiday/timeline period icon — replaces SF Symbol `calendar.day.timeline.left`.
        case rows
        case clock

        // MARK: - Filter / Sort

        case funnel
        case funnelFilled

        // MARK: - Communication / Misc

        case envelopeFilled
        case warning
        case warningCircleFilled
        case eye
        case eyeSlash
        case gear
        case info
        case mapPin
        /// Auth/credentials icon — closest match for SF Symbol `person.badge.key`.
        case key
        /// "Open externally" icon — closest match for SF Symbol `safari`.
        case openExternal
        case package
        case tray
        /// Debug tab icon — replaces SF Symbol `ant`.
        case bug
        case book
        /// Onboarding icon — replaces SF Symbol `book.pages`.
        case books
        /// Note entity icon — replaces SF Symbol `note.text`.
        case noteText

        // MARK: - Resolution

        var phosphorIcon: Ph {
            switch self {
            case .plus: .plus
            case .minus: .minus
            case .xmark: .x
            case .xmarkCircle, .xmarkCircleFilled: .xCircle
            case .checkmark: .check
            case .checkCircle, .checkCircleFilled: .checkCircle
            case .trash: .trash
            case .pencil: .pencil
            case .editCompose: .notePencil
            case .copy: .copy
            case .link: .link
            case .circle, .circleFilled: .circle
            case .star, .starFilled: .star
            case .tag, .tagFilled: .tag
            case .folder, .folderFilled: .folder
            case .arrowRight: .arrowRight
            case .arrowRightCircle, .arrowRightCircleFilled: .arrowCircleRight
            case .arrowUTurnLeft: .arrowUUpLeft
            case .caretDown: .caretDown
            case .caretRight: .caretRight
            case .caretLeft: .caretLeft
            case .arrowsUpDown: .arrowsDownUp
            case .swap: .swap
            case .arrowsClockwise: .arrowsClockwise
            case .cloudWarning: .cloudWarning
            case .cloud: .cloud
            case .calendar, .calendarFilled: .calendar
            case .calendarPlus: .calendarPlus
            case .calendarDots: .calendarDots
            case .sun, .sunFilled: .sun
            case .rows: .rows
            case .clock: .clock
            case .funnel, .funnelFilled: .funnel
            case .envelopeFilled: .envelope
            case .warning: .warning
            case .warningCircleFilled: .warningCircle
            case .eye: .eye
            case .eyeSlash: .eyeSlash
            case .gear: .gear
            case .info: .info
            case .mapPin: .mapPin
            case .key: .key
            case .openExternal: .arrowSquareOut
            case .package: .package
            case .tray: .tray
            case .bug: .bug
            case .book: .book
            case .books: .books
            case .noteText: .fileText
            }
        }

        var weight: Ph.IconWeight {
            switch self {
            case .xmarkCircleFilled, .checkCircleFilled, .circleFilled, .starFilled, .tagFilled,
                 .folderFilled, .arrowRightCircleFilled, .calendarFilled, .sunFilled, .funnelFilled,
                 .envelopeFilled, .warningCircleFilled:
                .fill
            default:
                .regular
            }
        }

        /// The resolved, ready-to-render icon image.
        var image: Image {
            phosphorIcon.weight(weight)
        }
    }
}
