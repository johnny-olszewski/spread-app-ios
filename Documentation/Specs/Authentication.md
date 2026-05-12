# Authentication

> Source: Documentation/spec.md

### Auth UI (v1)
- The auth button remains a trailing toolbar control in spread content views; the old Inbox toolbar group is removed because Inbox is now surfaced through the top-level search tab. [SPRD-84, SPRD-148]
- Auth button in toolbar, trailing the inbox group. [SPRD-84]
- Button appearance: [SPRD-84]
  - Logged out: person icon (`person.crop.circle`)
  - Logged in: filled person icon (`person.crop.circle.fill`)
- On launch in product environments with no valid session, a large auth sheet is presented as a blocking gate before journal content is accessible. [SPRD-106]
- Logged out state from the toolbar also opens the same auth sheet. [SPRD-106]
  - Sheet presentation uses `.large`-style sizing appropriate for iPhone and iPad.
  - Email and password fields
  - Sign In button (disabled until fields populated)
  - Inline error message display for failed login attempts
  - In-sheet navigation to Sign Up and Forgot Password
  - Sheet dismisses on successful login
- All password inputs (`SecureField`) across `LoginSheet`, `SignUpSheet`, and `SetNewPasswordSheet` include a show/hide toggle button (eye icon) so users can verify what they have typed. The toggle is inline at the trailing edge of each password field. [SPRD-208]
- When sign-in fails because the user's email is not yet confirmed, the error section in `LoginSheet` displays an additional "Resend verification email" button inline below the error message. Tapping it calls `resendVerification` using the current email field value. Loading state and errors from the resend call are shown inline. [SPRD-209]
- Logged in state: tapping button opens profile sheet. [SPRD-84]
  - Shows user email
  - Sign Out button in toolbar
  - Sign out requires confirmation alert (warns that local data will be wiped)
  - "Change Password" row navigates to `ChangePasswordSheet`. [SPRD-210]
  - "Delete Account" row in a separate destructive section presents a two-step confirmation before permanently deleting the account and all associated data. [SPRD-211]
  - "Legal" section contains links to Terms of Service and Privacy Policy, opening in Safari. [SPRD-212]
- Sign-up sheet footer displays "By creating an account you agree to our Terms of Service and Privacy Policy" with tappable links opening each document in Safari. [SPRD-212]
- `ChangePasswordSheet`: new password and confirm-password fields with visibility toggle; validation via `AuthFormValidator`; "Save Password" disabled until form valid or loading; `ProgressView` overlay during operation; errors shown inline; accessible via "Change Password" in `ProfileSheet`. No current-password field is required — the active authenticated session authorises the update. [SPRD-210]
- Apple and Google sign-in are not part of v1. [SPRD-108]
- If a previously authenticated user launches offline and the app has not definitively determined that the session is invalid, cached local data remains accessible and sync resumes when connectivity returns. [SPRD-106]
- If the app later determines online that the session is invalid or expired, it returns to the auth gate. [SPRD-106]

### Account Management (v1)

#### Change Password
- Authenticated users can change their password via a "Change Password" row in `ProfileSheet`. [SPRD-210]
- Tapping "Change Password" presents `ChangePasswordSheet` as a modal sheet.
- `ChangePasswordSheet` contains a new-password `SecureField` and a confirm-password `SecureField`, each with a show/hide toggle. Validation uses `AuthFormValidator.validatePassword` and `AuthFormValidator.validatePasswordConfirmation`.
- "Save Password" is disabled until both fields pass validation and no operation is in progress.
- A `ProgressView` overlay covers the form during the save operation.
- On success, the sheet dismisses automatically.
- Errors are shown inline within the sheet (same pattern as `SetNewPasswordSheet`).
- No current-password field is required; the active authenticated session authorises the update.

#### Delete Account
- Authenticated users can permanently delete their account via a "Delete Account" row in a dedicated destructive section of `ProfileSheet`. [SPRD-211]
- Tapping "Delete Account" presents a confirmation alert: "Delete Account?" with message "This will permanently delete your account and all associated data. This cannot be undone." and a destructive "Delete Account" action.
- If confirmed, the app calls a server-side `deleteAccount` operation (Supabase Edge Function `delete-user`), which deletes the Supabase auth record and cascades to all user data via RLS.
- On success, the local store is wiped and the app returns to the auth gate (same path as sign-out).
- Errors during deletion are surfaced via an alert: "Could not delete account. Please try again or contact support."
- The `ProfileSheet` "Delete Account" row and confirmation alert are gated behind the same `authManager.isLoading` guard so the action is disabled during any in-progress operation.
- `AuthService` gains a `deleteAccount()` method; `SupabaseAuthService` calls the `delete-user` Edge Function using the authenticated session; `MockAuthService` provides a no-op stub; `DebugAuthService` delegates to the wrapped service.
- `AuthManager` gains a `deleteAccount() async throws` method following the `isLoading`/`errorMessage`/`defer` pattern, and on success calls the existing sign-out path (`state = .signedOut`, `onSignOut()`).
- The `delete-user` Edge Function runs under the Supabase service role and deletes the calling user by extracting the user ID from the request's JWT. It must be deployed to both `spread-prod` and `spread-dev`.

#### Legal Links
- `SignUpSheet` shows a footer: "By creating an account you agree to our [Terms of Service] and [Privacy Policy]." Both are `Link` views that open the respective URL in Safari. [SPRD-212]
- `ProfileSheet` contains a "Legal" section with two rows: "Terms of Service" and "Privacy Policy", each opening the respective URL in Safari. [SPRD-212]
- URLs are defined in a single `LegalLinks` namespace (`enum LegalLinks`) to avoid duplication and make the pre-App Store URL update a one-line change.
- Placeholder URLs (`https://example.com/terms`, `https://example.com/privacy`) are used until production documents are published; a code comment marks each as a `TODO: replace before App Store submission`.

---

## Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19)

### Overview

`WKFLW-19` completes the auth flow for TestFlight. Supabase email confirmation is enabled in production. This means sign-up does not produce an immediate session; the user must verify their email before accessing journal content. Both the email verification link and the password reset link must deep-link back into the app rather than opening a web page. A `spread://` custom URL scheme handles both. [SPRD-200, SPRD-201, SPRD-202, SPRD-203, SPRD-204, SPRD-205, SPRD-206, SPRD-207]

> **Supabase config**: All redirect URL and auth configuration changes must be applied to both `spread-prod` and `spread-dev` projects. The allowed redirect URL `spread://auth/callback` must be added to Authentication → URL Configuration in the Supabase dashboard for each project.

### URL Scheme and Deeplink Routing

- The app registers the `spread` custom URL scheme in `Info.plist` (`CFBundleURLSchemes`). [SPRD-202]
- Supabase is configured to redirect email confirmation and password reset links to `spread://auth/callback`. [SPRD-202]
- An `AuthDeepLinkCoordinator` (`@Observable @MainActor final class`) handles all incoming URLs via `.onOpenURL` wired at the app root. [SPRD-202]
- The coordinator parses the URL type and calls `AuthService.handle(url:)` to exchange the token with Supabase. [SPRD-202]
- Two URL types are handled: [SPRD-202]
  - `type=signup`: email verification. Token exchange establishes a real session. The `authStateChanges` stream propagates the sign-in automatically. No additional routing is needed.
  - `type=recovery`: password reset. Token exchange establishes a temporary recovery session. The coordinator sets `isRecoverySession = true`, which the root view observes to present `SetNewPasswordSheet`. After the user sets a new password, the recovery session becomes a permanent session and `isRecoverySession` clears.
- If the user confirms their email on a different device, the deeplink does not open the app. The user opens the app manually and signs in. The login error mapping must handle the "email not confirmed" case explicitly so users who attempt to sign in before confirming receive a clear message rather than a generic failure. [SPRD-206]

### Sign-Up Flow (with Email Confirmation)

- After the user submits the sign-up form, `AuthService.signUp` succeeds but returns no session (Supabase email confirmation is enabled). [SPRD-203]
- `SignUpSheet` does not call `onSignIn` or dismiss. Instead it transitions to an in-sheet confirmation state. [SPRD-203]
- The confirmation state displays: [SPRD-203]
  - The submitted email address
  - Instructions: "Check your email at [address] and tap the verification link to continue."
  - A "Resend Email" button that calls `AuthManager.resendVerification(email:)`. Resend is rate-limited by Supabase; errors surface via `authManager.errorMessage`.
  - A "Done" button that dismisses the sheet (user can reopen it later via the auth toolbar button)
- Once the user taps the verification deeplink and the app signs them in automatically, the blocking auth gate (if presented) dismisses normally via the existing `authManager.state` observation. [SPRD-200, SPRD-202]

### Password Reset Flow

- The existing `ForgotPasswordSheet` already shows a success state after sending the reset email. No changes to that sheet. [SPRD-196]
- When the user taps the reset link, the `spread://auth/callback?type=recovery` URL opens the app. [SPRD-202]
- `AuthDeepLinkCoordinator` exchanges the token, sets `isRecoverySession = true`, and the root view presents `SetNewPasswordSheet` as a full-screen sheet. [SPRD-202, SPRD-204]
- `SetNewPasswordSheet` contains: [SPRD-204]
  - New password field (`textContentType(.newPassword)`)
  - Confirm password field
  - Validation via `AuthFormValidator` (minimum length, match)
  - Inline validation and server error display matching the existing auth sheet patterns
  - A "Save Password" toolbar button (disabled until the form is valid and not loading)
  - A `ProgressView` overlay when `authManager.isLoading`
- On success: the sheet dismisses, `isRecoverySession` clears, and the user lands in journal content. No additional sign-in step is required. [SPRD-204]
- `interactiveDismissDisabled(true)` is set on `SetNewPasswordSheet` so users cannot accidentally skip the step. A "Cancel" button is available that clears the recovery session and returns to the auth gate. [SPRD-204]

### Loading States

- `LoginSheet`, `SignUpSheet`, and `ForgotPasswordSheet` each show a `ProgressView` overlay when `authManager.isLoading == true`. [SPRD-205]
- The overlay sits above the form content and below the navigation bar.
- Existing button-disable behavior during loading is preserved. [SPRD-205]

### AuthService Protocol Additions

New methods added to `AuthService` and implemented in `SupabaseAuthService`, with stubs in `MockAuthService`: [SPRD-200]

- `handle(url: URL) async throws -> AuthDeepLinkResult` — exchanges a deeplink URL token for a session. Returns `.emailConfirmed(AuthSuccess)` or `.recoverySession`.
- `updatePassword(newPassword: String) async throws` — updates the authenticated user's password. Used post-recovery.
- `resendVerification(email: String) async throws` — resends the email confirmation link.
- `var authStateChanges: AsyncStream<AuthChangeEvent>` — emits `.signedOut` when the session is externally invalidated.

### Session Expiry

- `AuthManager.init` starts a stored `Task` that iterates `service.authStateChanges`. [SPRD-201]
- On a `.signedOut` event from the stream, `AuthManager` transitions state to `.signedOut` and calls `onSignOut`. [SPRD-201]
- This is the same path as a manual sign-out: local data is wiped via `AuthLifecycleCoordinator` and the auth gate is presented. [SPRD-201]
- The stream covers cases such as: session revoked from another device, refresh token expired after a long idle period, or admin-forced sign-out. [SPRD-201]

### Error Message Additions

The following Supabase error cases must produce specific human-readable messages in `AuthManager.mapAuthError`: [SPRD-206]

- `emailNotConfirmed` → "Please verify your email first. Check your inbox."
- `userAlreadyExists` / duplicate email on sign-up → "An account with this email already exists."
- Rate limiting → "Too many attempts. Please try again later."
- Network / timeout → "No internet connection. Please check your network and try again."

### Testing

- Automated smoke tests cover: login success and failure (wrong password, unconfirmed email), sign-up confirmation state, sign-up failure (email already exists), forgot-password submission success and error, password update success, session expiry state transition, and URL parsing for both deeplink types. [SPRD-207]
- Flows that require a real Supabase backend and a live email inbox cannot be covered by automated tests. These are documented in `Documentation/ManualTests.md`.
