import Foundation

/// Validates email and password fields for auth forms.
///
/// Provides client-side validation with user-friendly error messages
/// for the login and sign-up forms.
enum AuthFormValidator {

    /// Minimum password length requirement.
    static let minimumPasswordLength = 8

    /// Validates an email address format.
    ///
    /// - Parameter email: The email string to validate.
    /// - Returns: An error message if invalid, nil if valid.
    static func validateEmail(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return "Email is required."
        }

        // Basic email format: something@something.something
        let emailPattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        guard trimmed.range(of: emailPattern, options: .regularExpression) != nil else {
            return "Please enter a valid email address."
        }

        return nil
    }

    /// Validates a password against minimum requirements.
    ///
    /// - Parameter password: The password string to validate.
    /// - Returns: An error message if invalid, nil if valid.
    static func validatePassword(_ password: String) -> String? {
        guard !password.isEmpty else {
            return "Password is required."
        }

        guard password.count >= minimumPasswordLength else {
            return "Password must be at least \(minimumPasswordLength) characters."
        }

        return nil
    }

    /// Validates that a confirmation password matches the original.
    ///
    /// - Parameters:
    ///   - password: The original password.
    ///   - confirmation: The confirmation password.
    /// - Returns: An error message if they don't match, nil if they match.
    static func validatePasswordConfirmation(password: String, confirmation: String) -> String? {
        guard !confirmation.isEmpty else {
            return "Please confirm your password."
        }

        guard password == confirmation else {
            return "Passwords do not match."
        }

        return nil
    }
}
