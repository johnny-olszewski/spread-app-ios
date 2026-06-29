import SwiftUI
import UIKit
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
        /// Account/profile icon — replaces SF Symbol `person.crop.circle`.
        case userCircle
        /// Account/profile icon, signed-in state — replaces SF Symbol `person.crop.circle.fill`.
        case userCircleFilled
        /// Document icon — replaces SF Symbol `doc.text`.
        case document
        /// "Swap"/boundary icon — replaces SF Symbol `arrow.left.arrow.right`.
        case arrowsLeftRight
        /// Test-scenario icon — replaces SF Symbol `testtube.2`.
        case testTube

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
            case .userCircle, .userCircleFilled: .userCircle
            case .document: .fileText
            case .arrowsLeftRight: .arrowsLeftRight
            case .testTube: .testTube
            }
        }

        var weight: Ph.IconWeight {
            switch self {
            case .xmarkCircleFilled, .checkCircleFilled, .circleFilled, .starFilled, .tagFilled,
                 .folderFilled, .arrowRightCircleFilled, .calendarFilled, .sunFilled, .funnelFilled,
                 .envelopeFilled, .warningCircleFilled, .userCircleFilled:
                .fill
            default:
                .regular
            }
        }

        /// The resolved, ready-to-render icon image.
        var image: Image {
            phosphorIcon.weight(weight)
        }

        /// The icon sized to an explicit square frame.
        ///
        /// Unlike SF Symbols (font glyphs that inherit ambient `.font()` sizing automatically),
        /// Phosphor icons are plain resizable images with no intrinsic relationship to
        /// surrounding text size — every call site must size them explicitly. Defaults to
        /// `SpreadTheme.IconSize.medium`, matching the "standard inline icons" sizing SF Symbols
        /// fell back to when used without an explicit `.font()` size.
        ///
        /// Works for ordinary SwiftUI layout contexts. UIKit-bridged chrome (`Tab`'s
        /// floating-glass tab bar, `Picker`'s `.menu` style) does **not** reliably honor this —
        /// confirmed via manual visual verification for both: the icon rendered at the underlying
        /// asset's native resolution, ballooning to fill the tab bar / overlapping the calendar
        /// behind a `Picker`. Use `chromeImage(size:)` in those contexts instead.
        func sized(_ size: CGFloat = SpreadTheme.IconSize.medium) -> some View {
            image
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .fixedSize()
        }

        /// A pre-rasterized, fixed-pixel template image for icon slots inside UIKit-bridged
        /// chrome (`Tab`'s floating-glass tab bar, `Picker` with `.pickerStyle(.menu)`, and
        /// similar system components that don't render a live SwiftUI view tree for their icon).
        ///
        /// That chrome ignores SwiftUI `.frame()`/`.fixedSize()` on a live Phosphor `Image` — it
        /// extracts/lays out the icon through its own sizing pass instead of the normal SwiftUI
        /// layout protocol. Rasterizing to a `UIImage` at an exact pixel size and marking it
        /// `.alwaysTemplate` sidesteps this entirely: the chrome receives a literal fixed-size
        /// bitmap (nothing left to mis-measure) and `.alwaysTemplate` lets it still apply its own
        /// tint (e.g. selected/unselected tab state), matching how SF Symbols behave there.
        @MainActor
        func chromeImage(size: CGFloat = SpreadTheme.IconSize.medium) -> Image {
            let renderer = ImageRenderer(content: sized(size))
            renderer.scale = UIScreen.main.scale
            guard let uiImage = renderer.uiImage else { return image }
            return Image(uiImage: uiImage.withRenderingMode(.alwaysTemplate))
        }
    }
}

private struct IconColorBlend: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        // `.overlay` sizes the overlaying `Color` to `content`'s own resolved frame. A `ZStack`
        // here is the wrong tool: a bare `Color` view is greedy — it reports back whatever size
        // its parent proposes, up to infinity — so `ZStack { content; color }` would size itself
        // to the *largest* child, letting `color` balloon the whole result to fill all available
        // space in any context with generous surrounding room (this caused a real bug: the
        // floating "+" button's circle background filled almost the entire screen).
        content
            .overlay {
                color.blendMode(.sourceAtop)
            }
            .drawingGroup(opaque: false)
    }
}

extension View {
    /// Recolors a `SpreadTheme.Icon`'s image, mirroring PhosphorSwift's own `.color(_:)`
    /// modifier without requiring every call site to `import PhosphorSwift` directly —
    /// `SpreadTheme.Icon` is the intended boundary, not the underlying Phosphor module.
    func iconTint(_ color: Color) -> some View {
        modifier(IconColorBlend(color: color))
    }
}
