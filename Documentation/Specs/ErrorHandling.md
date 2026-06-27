# Error Handling

> **SPRD tasks**: SPRD-233
> Source: Documentation/spec.md

### Error Handling UX
- **Sign-in errors**: Error messages are displayed inline on the login sheet below the password field. Error text is human-readable and maps from auth error types: [SPRD-84, SPRD-206]
  - Invalid credentials: "Invalid email or password."
  - Email not confirmed: "Please verify your email first. Check your inbox." — followed by an inline "Resend verification email" button. [SPRD-209]
  - User not found: "No account found with this email."
  - Rate limited: "Too many attempts. Please try again later."
  - Network error: "No internet connection. Please check your network and try again."
  - Unmapped Supabase 4xx error: the Supabase message is cleaned (sentence-cased, trailing period added) and surfaced directly so users see specific API feedback for error codes not explicitly handled.
  - Any other failure: "Authentication failed. Please try again."
- **Sync errors**: Sync failures are non-blocking. Automatic retry occurs with exponential backoff (2s base, 300s max). A non-tappable error banner appears below the navigator strip with text "Last sync failed · Pull down to retry"; it clears on next successful sync. [SPRD-85, SPRD-134, SPRD-135]
- **Network errors**: When offline, the app continues to function normally with local data. When connectivity returns, sync resumes automatically. Offline state is surfaced in the pull-to-refresh indicator only ("Offline"); no persistent banner is shown. [SPRD-85, SPRD-134, SPRD-135]
- **App initialization errors**: If the SwiftData container fails to create on launch, the app shows a fatal error screen with a message to restart the app. No recovery is attempted. [SPRD-TBD]
- **Entry deletion**: Requires confirmation via a standard destructive alert ("Delete this task? This cannot be undone."). [SPRD-24]
- **Spread deletion**: Requires confirmation with a message explaining that entries will be reassigned, not deleted. [SPRD-15]

---

## Alert Infrastructure Refactor (SPRD-233)

### Design Decision: Generic AlertModel replacing typed AlertDestination cases

- **Context**: `SpreadsCoordinator.AlertDestination` had one case per alert scenario (deleteSpreadConfirmation, deleteSpreadFailed, discardChanges, deleteEntryConfirmation). Adding new alerts required growing the enum and duplicating coordinator factory methods. Cases with identical structure (title + message + two buttons) couldn't be reused.
- **Decision**: Replace the multi-case `AlertDestination` enum with a single `.alert(AlertModel)` case. `AlertModel` is a fully generic struct carrying `title: String`, `message: String?`, and `buttons: [AlertModel.Button]`. Each button has `label: String`, `role: ButtonRole?`, and `action: (@MainActor () async -> Void)?`. Static presets (e.g. `AlertModel.deleteSpreadConfirmation(spread:)`) live as static factory methods on `AlertModel` itself — not on the coordinator.
- **Rationale**: Fully generic — any alert the app needs can be expressed without touching the enum. Static presets keep alert definitions co-located with the model rather than scattered through coordinator action methods. Coordinator action methods (`showDeleteSpreadConfirmation`, etc.) remain but construct `AlertModel` inline rather than setting a typed enum case.
- **SPRD reference**: SPRD-233
