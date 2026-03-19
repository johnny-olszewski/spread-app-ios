import Testing
@testable import Spread

/// Tests for email and password validation logic.
///
/// Validates that AuthFormValidator correctly identifies valid and invalid
/// inputs for auth forms.
@Suite("Auth Form Validator Tests")
struct AuthFormValidatorTests {

    // MARK: - Email Validation

    /// Conditions: Valid email address.
    /// Expected: No error.
    @Test("Valid email returns nil")
    func validEmailReturnsNil() {
        #expect(AuthFormValidator.validateEmail("user@example.com") == nil)
    }

    /// Conditions: Email with subdomain.
    /// Expected: No error.
    @Test("Email with subdomain is valid")
    func emailWithSubdomainIsValid() {
        #expect(AuthFormValidator.validateEmail("user@mail.example.com") == nil)
    }

    /// Conditions: Empty email.
    /// Expected: Error about required email.
    @Test("Empty email returns error")
    func emptyEmailReturnsError() {
        let error = AuthFormValidator.validateEmail("")
        #expect(error != nil)
        #expect(error == "Email is required.")
    }

    /// Conditions: Whitespace-only email.
    /// Expected: Error about required email.
    @Test("Whitespace-only email returns error")
    func whitespaceOnlyEmailReturnsError() {
        let error = AuthFormValidator.validateEmail("   ")
        #expect(error != nil)
        #expect(error == "Email is required.")
    }

    /// Conditions: Email without @ symbol.
    /// Expected: Error about invalid format.
    @Test("Email without @ is invalid")
    func emailWithoutAtIsInvalid() {
        let error = AuthFormValidator.validateEmail("userexample.com")
        #expect(error != nil)
        #expect(error == "Please enter a valid email address.")
    }

    /// Conditions: Email without domain.
    /// Expected: Error about invalid format.
    @Test("Email without domain is invalid")
    func emailWithoutDomainIsInvalid() {
        let error = AuthFormValidator.validateEmail("user@")
        #expect(error != nil)
        #expect(error == "Please enter a valid email address.")
    }

    /// Conditions: Email without TLD.
    /// Expected: Error about invalid format.
    @Test("Email without TLD is invalid")
    func emailWithoutTLDIsInvalid() {
        let error = AuthFormValidator.validateEmail("user@example")
        #expect(error != nil)
        #expect(error == "Please enter a valid email address.")
    }

    // MARK: - Password Validation

    /// Conditions: Password meets minimum length.
    /// Expected: No error.
    @Test("Valid password returns nil")
    func validPasswordReturnsNil() {
        #expect(AuthFormValidator.validatePassword("password123") == nil)
    }

    /// Conditions: Password exactly at minimum length.
    /// Expected: No error.
    @Test("Password at minimum length is valid")
    func passwordAtMinimumLengthIsValid() {
        let password = String(repeating: "a", count: AuthFormValidator.minimumPasswordLength)
        #expect(AuthFormValidator.validatePassword(password) == nil)
    }

    /// Conditions: Empty password.
    /// Expected: Error about required password.
    @Test("Empty password returns error")
    func emptyPasswordReturnsError() {
        let error = AuthFormValidator.validatePassword("")
        #expect(error != nil)
        #expect(error == "Password is required.")
    }

    /// Conditions: Password below minimum length.
    /// Expected: Error about minimum length.
    @Test("Short password returns error")
    func shortPasswordReturnsError() {
        let error = AuthFormValidator.validatePassword("short")
        #expect(error != nil)
        #expect(error == "Password must be at least \(AuthFormValidator.minimumPasswordLength) characters.")
    }

    // MARK: - Password Confirmation

    /// Conditions: Confirmation matches password.
    /// Expected: No error.
    @Test("Matching passwords return nil")
    func matchingPasswordsReturnNil() {
        #expect(AuthFormValidator.validatePasswordConfirmation(
            password: "password123",
            confirmation: "password123"
        ) == nil)
    }

    /// Conditions: Empty confirmation.
    /// Expected: Error about confirming password.
    @Test("Empty confirmation returns error")
    func emptyConfirmationReturnsError() {
        let error = AuthFormValidator.validatePasswordConfirmation(
            password: "password123",
            confirmation: ""
        )
        #expect(error != nil)
        #expect(error == "Please confirm your password.")
    }

    /// Conditions: Confirmation does not match.
    /// Expected: Error about mismatch.
    @Test("Mismatched passwords return error")
    func mismatchedPasswordsReturnError() {
        let error = AuthFormValidator.validatePasswordConfirmation(
            password: "password123",
            confirmation: "password456"
        )
        #expect(error != nil)
        #expect(error == "Passwords do not match.")
    }
}
