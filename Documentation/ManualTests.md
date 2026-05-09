# Manual Test Cases

Some flows cannot be covered by automated tests because they require a live Supabase backend, real email delivery, a registered `spread://` URL scheme on a physical or simulator device, and correct Supabase dashboard configuration. This file documents those cases with enough detail to execute them consistently before each TestFlight build.

## Prerequisites (run once before any test below)

| Step | Action | Expected |
|---|---|---|
| 1 | In the Supabase dashboard, open **spread-prod** → Authentication → URL Configuration → Redirect URLs | `spread://auth/callback` is present. If not, add it and save. |
| 2 | Repeat step 1 for **spread-dev** | Same. Both projects must have the redirect URL. |
| 3 | Confirm **Email Confirmations** is toggled ON in spread-prod → Authentication → Providers → Email | Toggle is on. |
| 4 | Repeat step 3 for spread-dev | Same. |
| 5 | Build and install the app on a device or simulator with a valid email account accessible on the same device | App launches and shows the auth gate. |

---

## MT-01: Email Verification Deeplink (Sign-Up → Confirm → Auto Sign-In)

**What this tests**: The full sign-up flow when email confirmation is enabled. Verifies that the in-sheet confirmation state appears, the verification link routes back into the app, and the user is signed in automatically.

**Setup**:
- App is installed and at the auth gate (not signed in).
- Use an email address you can receive messages on from the same device (e.g., a mail app is open in the background).
- The Supabase prerequisite steps above are complete.

**Steps**:

| # | Action | Expected Result |
|---|---|---|
| 1 | Tap "Create Account" on the login sheet | `SignUpSheet` opens |
| 2 | Enter a valid email and a password (8+ characters) with confirmation | Fields are filled, "Create" button is enabled |
| 3 | Tap "Create" | The sheet transitions to the "Check your email" confirmation state. The submitted email address is shown. No crash, no dismiss. |
| 4 | Open your email app and find the verification email from Supabase | Email arrives within ~1 minute. Subject contains "Confirm your email". |
| 5 | Tap the verification link in the email | iOS shows a prompt to open the link in Spread, or opens the app directly |
| 6 | Confirm "Open in Spread" if prompted | App comes to foreground |
| 7 | Observe app state | User is signed in. Journal content is visible. If this is the first sign-in, the onboarding sheet appears. |

**Details**:
- If the link opens a browser instead of the app, the `spread://` URL scheme is not registered correctly in `Info.plist` or the Supabase redirect URL is misconfigured.
- The verification link expires after 1 hour by default (configurable in Supabase). If the link has expired, Supabase will show an error page rather than routing to the app.

---

## MT-02: Resend Verification Email

**What this tests**: The "Resend Email" button in the sign-up confirmation state delivers a new verification email.

**Setup**:
- Begin from MT-01 step 3 (sheet is in the confirmation state).
- Do not tap the original verification link yet.

**Steps**:

| # | Action | Expected Result |
|---|---|---|
| 1 | Tap "Resend Email" in the confirmation state | A brief loading state appears (ProgressView), then clears |
| 2 | Check your email inbox | A new verification email arrives. The original link may still work or may be invalidated depending on Supabase configuration. |
| 3 | Tap the link in the new email | App signs the user in (same as MT-01 step 7) |

**Details**:
- Supabase rate-limits resend requests. If you tap "Resend Email" too quickly, the error message "Too many attempts. Please try again later." should appear. Wait ~60 seconds and try again.

---

## MT-03: Password Reset Deeplink (Forgot Password → Set New Password → Auto Sign-In)

**What this tests**: The full password reset flow. Verifies the reset email routes back into the app, `SetNewPasswordSheet` appears, and the user is signed in after saving.

**Setup**:
- App is installed and at the auth gate (not signed in).
- Use an existing account whose email you can receive on the same device.
- The Supabase prerequisite steps above are complete.

**Steps**:

| # | Action | Expected Result |
|---|---|---|
| 1 | Tap "Forgot Password?" on the login sheet | `ForgotPasswordSheet` opens |
| 2 | Enter the email of an existing account | Email field is filled, "Send" button is enabled |
| 3 | Tap "Send" | Sheet shows "Reset Link Sent" success state with the email address shown |
| 4 | Open your email app and find the password reset email from Supabase | Email arrives within ~1 minute. Subject contains "Reset your password". |
| 5 | Tap the reset link in the email | iOS opens the app directly or shows an "Open in Spread" prompt |
| 6 | Confirm "Open in Spread" if prompted | App comes to foreground |
| 7 | Observe app state | `SetNewPasswordSheet` is presented as a full-screen sheet over the auth gate |
| 8 | Enter a new password (8+ characters) and confirm it | Both fields filled, "Save Password" is enabled |
| 9 | Tap "Save Password" | ProgressView appears briefly, then sheet dismisses |
| 10 | Observe app state | User is signed in. Journal content is visible. |

**Details**:
- Password reset links expire after 1 hour by default. If the link is expired, Supabase routes to an error page instead of the app.
- If `SetNewPasswordSheet` does not appear, check that `AuthDeepLinkCoordinator` is wired to `.onOpenURL` in the app root and that `spread://auth/callback` is listed as a Supabase redirect URL.

---

## MT-04: Cancel Password Reset Mid-Flow

**What this tests**: Tapping "Cancel" on `SetNewPasswordSheet` returns the user to the auth gate without setting a new password.

**Setup**:
- Begin from MT-03 step 7 (`SetNewPasswordSheet` is visible).

**Steps**:

| # | Action | Expected Result |
|---|---|---|
| 1 | Tap "Cancel" on `SetNewPasswordSheet` | Sheet dismisses |
| 2 | Observe app state | Auth gate is visible (login sheet or blocking gate). User is not signed in. |
| 3 | Sign in with the original password | Sign-in succeeds (password was not changed) |

---

## MT-05: Cross-Device Email Confirmation

**What this tests**: The graceful degradation path when the user confirms on a different device than the one they signed up on.

**Setup**:
- Sign up on one device/simulator (Device A). Reach the "Check your email" confirmation state.
- Access the verification email on a different device or desktop browser (Device B).

**Steps**:

| # | Action | Expected Result |
|---|---|---|
| 1 | On Device B, tap or click the verification link | A browser opens the Supabase confirmation page. The app does not open on Device A. |
| 2 | On Device A, tap "Done" to dismiss the confirmation sheet | Sheet dismisses. Auth gate is visible. |
| 3 | On Device A, tap "Sign In" and enter credentials | Sign-in succeeds (email is now confirmed). User lands in journal content. |

**Details**:
- If the user attempts to sign in on Device A before confirming (skipping step 1), the error "Please verify your email first. Check your inbox." should appear.

---

## MT-06: Supabase Dashboard — Redirect URL Configuration

**What this tests**: The one-time Supabase configuration required for all deeplinks to work. Run this once during initial WKFLW-19 setup, then re-verify after any Supabase project configuration change.

**Steps — spread-prod**:

| # | Action | Expected Result |
|---|---|---|
| 1 | Open Supabase dashboard → spread-prod → Authentication → URL Configuration | URL Configuration page is open |
| 2 | Under "Redirect URLs", verify `spread://auth/callback` is present | Entry exists |
| 3 | If missing: click "Add URL", enter `spread://auth/callback`, click "Save" | URL is saved |

**Steps — spread-dev**:

| # | Action | Expected Result |
|---|---|---|
| 1 | Open Supabase dashboard → spread-dev → Authentication → URL Configuration | URL Configuration page is open |
| 2 | Under "Redirect URLs", verify `spread://auth/callback` is present | Entry exists |
| 3 | If missing: click "Add URL", enter `spread://auth/callback`, click "Save" | URL is saved |

**Details**:
- Without this configuration, Supabase will not redirect to `spread://auth/callback` and deeplinks will open a browser error page instead of the app.
- Both projects must be configured identically. The dev project is used for all non-production testing including TestFlight QA builds.
