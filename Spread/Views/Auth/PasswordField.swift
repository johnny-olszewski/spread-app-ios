import SwiftUI

/// A text field for password input that allows the user to toggle visibility.
///
/// Renders a `SecureField` by default. Tapping the eye icon switches to a
/// plain `TextField` so the user can confirm what they typed. Both fields
/// share the same binding and placeholder text.
///
/// Use `isNewPassword: true` for new-password or confirm-password fields
/// (sets `.newPassword` text content type). Leave at the default for
/// sign-in password fields (`.password` content type).
struct PasswordField: View {

    // MARK: - Properties

    /// The placeholder label shown inside the field.
    let placeholder: String

    /// The current password text.
    @Binding var text: String

    /// When `true`, applies `.newPassword` content type (sign-up/reset flows).
    /// When `false`, applies `.password` content type (sign-in flow).
    var isNewPassword: Bool = false

    // MARK: - State

    @State private var isVisible = false

    // MARK: - Body

    var body: some View {
        HStack {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textContentType(isNewPassword ? .newPassword : .password)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.PasswordField.textField
                        )
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(isNewPassword ? .newPassword : .password)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.PasswordField.secureField
                        )
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.PasswordField.visibilityToggle)
        }
    }
}

// MARK: - Previews

#Preview("Hidden") {
    Form {
        PasswordField(placeholder: "Password", text: .constant(""))
        PasswordField(placeholder: "Password", text: .constant("secret123"))
    }
}

#Preview("Visible") {
    Form {
        PasswordField(placeholder: "Password", text: .constant("secret123"))
    }
}

#Preview("New Password") {
    Form {
        PasswordField(placeholder: "New Password", text: .constant(""), isNewPassword: true)
        PasswordField(placeholder: "Confirm Password", text: .constant(""), isNewPassword: true)
    }
}
