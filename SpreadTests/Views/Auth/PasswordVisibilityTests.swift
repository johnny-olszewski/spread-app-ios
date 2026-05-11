import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Unit tests for `PasswordField` and related accessibility identifiers.
///
/// These tests verify the API surface and static configuration of `PasswordField`.
/// Toggle behavior and rendering are covered by Xcode Previews and manual testing.
@MainActor
struct PasswordVisibilityTests {

    // MARK: - Accessibility Identifiers

    /// Conditions: The accessibility identifier constants are declared in
    /// `Definitions.AccessibilityIdentifiers.PasswordField`.
    /// Expected: Each identifier is non-empty, unique, and has the expected prefix.
    @Test func passwordFieldIdentifiers_areUnique() {
        let ids = [
            Definitions.AccessibilityIdentifiers.PasswordField.secureField,
            Definitions.AccessibilityIdentifiers.PasswordField.textField,
            Definitions.AccessibilityIdentifiers.PasswordField.visibilityToggle,
        ]

        // All non-empty
        for id in ids {
            #expect(!id.isEmpty)
        }

        // All unique
        let unique = Set(ids)
        #expect(unique.count == ids.count)
    }

    /// Conditions: The accessibility identifier constants for `PasswordField`.
    /// Expected: Each identifier uses the `auth.passwordField` prefix for namespacing.
    @Test func passwordFieldIdentifiers_haveCorrectPrefix() {
        #expect(
            Definitions.AccessibilityIdentifiers.PasswordField.secureField
                .hasPrefix("auth.passwordField")
        )
        #expect(
            Definitions.AccessibilityIdentifiers.PasswordField.textField
                .hasPrefix("auth.passwordField")
        )
        #expect(
            Definitions.AccessibilityIdentifiers.PasswordField.visibilityToggle
                .hasPrefix("auth.passwordField")
        )
    }

    // MARK: - PasswordField Default Configuration

    /// Conditions: A `PasswordField` is created with default parameters.
    /// Expected: `isNewPassword` defaults to `false` (sign-in content type path).
    @Test func passwordField_defaultIsNewPassword_isFalse() {
        var text = ""
        let field = PasswordField(placeholder: "Password", text: .init(get: { text }, set: { text = $0 }))
        #expect(field.isNewPassword == false)
    }

    /// Conditions: A `PasswordField` is created with `isNewPassword: true`.
    /// Expected: The property reflects the value passed at init.
    @Test func passwordField_isNewPassword_reflectsInitValue() {
        var text = ""
        let field = PasswordField(
            placeholder: "New Password",
            text: .init(get: { text }, set: { text = $0 }),
            isNewPassword: true
        )
        #expect(field.isNewPassword == true)
    }

    // MARK: - Secure vs Text Field Identifier Distinctness

    /// Conditions: The `secureField` and `textField` identifier constants are distinct.
    /// Expected: They do not share the same string value, ensuring that
    /// UI tests can distinguish between the hidden and revealed input states.
    @Test func passwordFieldIdentifiers_secureAndTextAreDistinct() {
        let secure = Definitions.AccessibilityIdentifiers.PasswordField.secureField
        let plain = Definitions.AccessibilityIdentifiers.PasswordField.textField
        #expect(secure != plain)
    }
}
