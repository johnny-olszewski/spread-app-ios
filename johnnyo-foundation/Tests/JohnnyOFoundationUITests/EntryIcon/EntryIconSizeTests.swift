import Testing
import SwiftUI
@testable import JohnnyOFoundationUI

struct EntryIconSizeTests {

    // MARK: - Named text styles

    /// Conditions: Text style is .largeTitle.
    /// Expected: Maps to 34pt.
    @Test func largeTitleMapsto34Points() {
        #expect(EntryIconSize(.largeTitle).points == 34)
    }

    /// Conditions: Text style is .title.
    /// Expected: Maps to 28pt.
    @Test func titleMapsto28Points() {
        #expect(EntryIconSize(.title).points == 28)
    }

    /// Conditions: Text style is .title2.
    /// Expected: Maps to 22pt.
    @Test func title2Mapsto22Points() {
        #expect(EntryIconSize(.title2).points == 22)
    }

    /// Conditions: Text style is .title3.
    /// Expected: Maps to 20pt.
    @Test func title3Mapsto20Points() {
        #expect(EntryIconSize(.title3).points == 20)
    }

    /// Conditions: Text style is .headline.
    /// Expected: Maps to 17pt.
    @Test func headlineMapsto17Points() {
        #expect(EntryIconSize(.headline).points == 17)
    }

    /// Conditions: Text style is .subheadline.
    /// Expected: Maps to 15pt.
    @Test func subheadlineMapsto15Points() {
        #expect(EntryIconSize(.subheadline).points == 15)
    }

    /// Conditions: Text style is .body.
    /// Expected: Maps to 17pt.
    @Test func bodyMapsto17Points() {
        #expect(EntryIconSize(.body).points == 17)
    }

    /// Conditions: Text style is .callout.
    /// Expected: Maps to 16pt.
    @Test func calloutMapsto16Points() {
        #expect(EntryIconSize(.callout).points == 16)
    }

    /// Conditions: Text style is .footnote.
    /// Expected: Maps to 13pt.
    @Test func footnoteMapsto13Points() {
        #expect(EntryIconSize(.footnote).points == 13)
    }

    /// Conditions: Text style is .caption.
    /// Expected: Maps to 12pt.
    @Test func captionMapsto12Points() {
        #expect(EntryIconSize(.caption).points == 12)
    }

    /// Conditions: Text style is .caption2.
    /// Expected: Maps to 11pt.
    @Test func caption2Mapsto11Points() {
        #expect(EntryIconSize(.caption2).points == 11)
    }

    // MARK: - Ordering

    /// Conditions: All named text styles are mapped.
    /// Expected: Point sizes are ordered largest to smallest with no ties except body/headline.
    @Test func pointSizesDecreaseWithTextStyleHierarchy() {
        let sizes: [CGFloat] = [
            EntryIconSize(.largeTitle).points,
            EntryIconSize(.title).points,
            EntryIconSize(.title2).points,
            EntryIconSize(.title3).points,
            EntryIconSize(.body).points,    // headline and body share 17pt
            EntryIconSize(.callout).points,
            EntryIconSize(.footnote).points,
            EntryIconSize(.caption).points,
            EntryIconSize(.caption2).points,
        ]
        for i in 0..<(sizes.count - 1) {
            #expect(sizes[i] >= sizes[i + 1])
        }
    }

    // MARK: - Positive values

    /// Conditions: Any valid text style.
    /// Expected: The resulting point size is always positive.
    @Test func allSizesArePositive() {
        let styles: [Font.TextStyle] = [
            .largeTitle, .title, .title2, .title3,
            .headline, .subheadline, .body, .callout,
            .footnote, .caption, .caption2
        ]
        for style in styles {
            #expect(EntryIconSize(style).points > 0)
        }
    }
}
