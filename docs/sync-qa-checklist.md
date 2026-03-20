# Sync QA Checklist

Manual verification checklist for the offline-first sync system. Run through these scenarios after any change to sync, auth, or data model code.

## Prerequisites

- Access to both **development** and **production** Supabase dashboards
- Two test accounts (one per environment, or the same email registered in both)
- A physical device or simulator with network control (Airplane Mode)
- Debug build with the Debug menu enabled

## 1. Push — Local Edits Sync to Server

### 1.1 Create Entities Offline, Then Sync

1. Enable Airplane Mode.
2. Create a spread, task, note, and event.
3. Open Debug menu > Sync Status. Confirm outbox count reflects the new mutations.
4. Disable Airplane Mode.
5. Wait for auto-sync (or trigger manually from Debug menu).
6. Verify outbox count drops to 0.
7. Check Supabase Dashboard > Table Editor. Confirm all entities exist with correct field values.

### 1.2 Update Entities Offline, Then Sync

1. While online, create a task and wait for sync to complete.
2. Enable Airplane Mode.
3. Edit the task title, change status to complete, update date.
4. Confirm outbox count increases.
5. Disable Airplane Mode and wait for sync.
6. Verify the server row has the updated title, status, and date.
7. Verify per-field `*_updated_at` timestamps match the local edit time.

### 1.3 Delete Entities Offline, Then Sync

1. While online, create a note and wait for sync.
2. Enable Airplane Mode.
3. Delete the note.
4. Disable Airplane Mode and wait for sync.
5. Verify the server row has `deleted_at` set (soft delete).
6. Verify the note no longer appears in the app.

## 2. Pull — Server Changes Sync to Device

### 2.1 New Entities From Server

1. Using Supabase Dashboard SQL Editor, insert a new task for the test user.
2. Trigger sync in the app (background or manual).
3. Verify the task appears in the correct spread.

### 2.2 Updated Entities From Server

1. Using SQL Editor, update an existing task's title on the server.
2. Trigger sync.
3. Verify the title change is reflected in the app.

### 2.3 Deleted Entities From Server

1. Using SQL Editor, set `deleted_at = now()` on a task.
2. Trigger sync.
3. Verify the task no longer appears in the app.

## 3. Conflict Resolution

### 3.1 Field-Level Last-Write-Wins

1. While online, create a task titled "Original" and wait for sync.
2. Enable Airplane Mode.
3. Change the title to "Local Edit".
4. Using SQL Editor, update the same task's title to "Server Edit" on the server (set `title_updated_at` to a timestamp older than your local edit).
5. Disable Airplane Mode and sync.
6. **Expected**: The task title is "Local Edit" (local timestamp is newer).

### 3.2 Delete-Wins

1. While online, create a task and wait for sync.
2. Enable Airplane Mode.
3. Edit the task's title locally.
4. Using SQL Editor, soft-delete the task on the server (set `deleted_at = now()`).
5. Disable Airplane Mode and sync.
6. **Expected**: The task is deleted (delete-wins policy).

### 3.3 Concurrent Edits to Different Fields

1. Create a task online and sync.
2. Enable Airplane Mode.
3. Change the title locally.
4. Using SQL Editor, change the status on the server.
5. Disable Airplane Mode and sync.
6. **Expected**: Both changes merge — title from local, status from server (field-level LWW).

## 4. Environment Switching

### 4.1 Switch With Empty Outbox

1. Sign in on the development environment.
2. Ensure outbox count is 0 (fully synced).
3. Open Debug menu > Data Environment > switch to production.
4. **Expected**: Switch proceeds immediately. App shows restart prompt. After restart, app connects to production Supabase.

### 4.2 Switch With Pending Outbox

1. Enable Airplane Mode while on development.
2. Create some entries (outbox count > 0).
3. Open Debug menu > Data Environment > switch to production.
4. **Expected**: Warning shown with outbox count. User must confirm to proceed (data loss).
5. Confirm the switch.
6. **Expected**: Local data wiped, sync state reset, restart prompt shown.

### 4.3 Cancel Switch

1. Same setup as 4.2 (pending outbox).
2. When warning appears, cancel the switch.
3. **Expected**: No data lost, outbox unchanged, environment unchanged.

## 5. Sign-In and Data Merge

### 5.1 First Sign-In With No Local Data

1. Fresh install or wiped app (no spreads, tasks, etc.).
2. Sign in with backup entitlement.
3. **Expected**: No migration prompt. Sync starts pulling server data.

### 5.2 First Sign-In With Local Data

1. Create entries while signed out.
2. Sign in with backup entitlement.
3. **Expected**: Migration prompt appears asking to merge or discard local data.
4. Choose "Merge".
5. **Expected**: Local entries are pushed to server. Server entries are pulled.

### 5.3 First Sign-In — Discard

1. Create entries while signed out.
2. Sign in with backup entitlement.
3. Choose "Discard" at the migration prompt.
4. **Expected**: Local data wiped. Only server data remains.

### 5.4 Sign-In Without Backup Entitlement

1. Sign in with an account that does NOT have backup entitlement.
2. **Expected**: Sync status shows "Backup unavailable". No sync attempts made.

### 5.5 Sign-Out

1. While signed in with synced data, sign out.
2. Confirm the sign-out warning.
3. **Expected**: Local data wiped. Sync state reset to idle.

## 6. Network Resilience

### 6.1 Sync Retry With Backoff

1. Sign in and enable Airplane Mode mid-sync (or use Debug sync policy to force failure).
2. **Expected**: Sync status shows error. Retries with exponential backoff (2s, 4s, 8s, ...).
3. Re-enable network.
4. **Expected**: Next retry succeeds. Status returns to "synced".

### 6.2 Auto-Sync on Foreground

1. Background the app.
2. Make a server-side change via SQL Editor.
3. Bring app to foreground.
4. **Expected**: Auto-sync triggers and pulls the change.

### 6.3 Auto-Sync on Connectivity Restore

1. Enable Airplane Mode.
2. Create local edits.
3. Disable Airplane Mode.
4. **Expected**: Sync triggers automatically and pushes edits.

## 7. Parent-Child Ordering

### 7.1 Create Assignment Before Spread

1. Enable Airplane Mode.
2. Create a spread, then add a task to that spread (creates task + task_assignment).
3. Disable Airplane Mode and sync.
4. **Expected**: Spread is pushed first (sync order 0), then task (order 1), then task_assignment (order 2). No FK constraint violations.

## 8. Debug Menu Verification

### 8.1 Sync Status Display

1. Check Debug menu > Sync Status section.
2. Verify it shows: current status, last sync date, outbox count.

### 8.2 Sync Log

1. Trigger several sync operations (success, failure, offline).
2. Check Debug menu > Sync Log.
3. Verify entries appear with correct timestamps and severity levels.
