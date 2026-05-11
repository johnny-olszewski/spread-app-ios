import Foundation
import Testing
@testable import Spread

/// Unit tests for `LegalLinks` URL constants and legal-link accessibility identifiers.
@MainActor
struct LegalLinksTests {

    // MARK: - URL Validity

    /// Conditions: `LegalLinks.termsOfService` is defined.
    /// Expected: The URL is non-nil and uses the `https` scheme.
    @Test func legalLinks_termsURL_isValid() {
        let url = LegalLinks.termsOfService
        #expect(url.scheme == "https")
        #expect(!url.absoluteString.isEmpty)
    }

    /// Conditions: `LegalLinks.privacyPolicy` is defined.
    /// Expected: The URL is non-nil and uses the `https` scheme.
    @Test func legalLinks_privacyURL_isValid() {
        let url = LegalLinks.privacyPolicy
        #expect(url.scheme == "https")
        #expect(!url.absoluteString.isEmpty)
    }

    /// Conditions: Both legal URL constants are defined.
    /// Expected: They are distinct URLs (not identical).
    @Test func legalLinks_URLsAreDistinct() {
        #expect(LegalLinks.termsOfService != LegalLinks.privacyPolicy)
    }

    // MARK: - Accessibility Identifiers: SignUpSheet

    /// Conditions: Accessibility identifiers for legal links in `SignUpSheet`.
    /// Expected: Both identifiers are non-empty and unique within the sign-up context.
    @Test func signUpSheet_legalFooterAccessibilityIdentifiers_present() {
        let ids = [
            Definitions.AccessibilityIdentifiers.LegalLinks.signUpTermsOfService,
            Definitions.AccessibilityIdentifiers.LegalLinks.signUpPrivacyPolicy,
        ]
        for id in ids {
            #expect(!id.isEmpty)
        }
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - Accessibility Identifiers: ProfileSheet

    /// Conditions: Accessibility identifiers for legal rows in `ProfileSheet`.
    /// Expected: Both identifiers are non-empty and unique within the profile context.
    @Test func profileSheet_legalSectionAccessibilityIdentifiers_present() {
        let ids = [
            Definitions.AccessibilityIdentifiers.LegalLinks.profileTermsOfService,
            Definitions.AccessibilityIdentifiers.LegalLinks.profilePrivacyPolicy,
        ]
        for id in ids {
            #expect(!id.isEmpty)
        }
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - Identifier Uniqueness Across Surfaces

    /// Conditions: All four legal-link accessibility identifiers are defined.
    /// Expected: All four are unique — sign-up and profile identifiers do not collide.
    @Test func legalLinks_allIdentifiers_areGloballyUnique() {
        let ids = [
            Definitions.AccessibilityIdentifiers.LegalLinks.signUpTermsOfService,
            Definitions.AccessibilityIdentifiers.LegalLinks.signUpPrivacyPolicy,
            Definitions.AccessibilityIdentifiers.LegalLinks.profileTermsOfService,
            Definitions.AccessibilityIdentifiers.LegalLinks.profilePrivacyPolicy,
        ]
        #expect(Set(ids).count == ids.count)
    }
}
