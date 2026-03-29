# Sync QA Checklist

Manual verification checklist for the simplified v1 sync model. This checklist separates product-environment behavior from Debug `localhost` so removed flows do not drift back into QA.

## Scope

- Product environments: Debug default (`development`), QA (`development`), Release (`production`)
- Debug-only engineering mode: `-DataEnvironment localhost`
- Local sync test environment: local Supabase with explicit `-SupabaseURL` / `-SupabaseKey` overrides

## Prerequisites

- Access to both development and production Supabase dashboards
- Two test accounts, or one email registered in both environments
- A device or simulator that can toggle Airplane Mode
- A Debug build for Debug-menu scenarios
- For destructive durability/rebuild checks, local Supabase started and reset via `./scripts/local-supabase.sh`

## 1. Product Environment Auth Gate

### 1.1 Signed-Out Launch Is Blocked

1. Launch the app in a product environment with no valid session.
2. Verify a large auth sheet blocks access before journal content appears.
3. Verify sign-in, sign-up, and forgot-password entry points are available.

### 1.2 Signed-In Launch Opens Normally

1. Sign in with email/password.
2. Relaunch the app while the session is still valid.
3. Verify the app opens directly into journal content.
4. Verify onboarding appears only on the first authenticated launch.

### 1.3 Offline Launch With Cached Session

1. Sign in successfully in a product environment.
2. Fully quit the app.
3. Enable Airplane Mode.
4. Relaunch the app.
5. Verify cached local data remains accessible and the app does not fall back to the auth gate.

### 1.4 Sign-Out Wipes Local Data

1. Sign in and allow data to sync locally.
2. Use the profile sheet to sign out.
3. Confirm the sign-out warning.
4. Verify local data is wiped and the app returns to the auth gate.

## 2. Push and Pull Sync

### 2.1 Create Entities Offline, Then Sync

1. Sign in to a product environment.
2. Enable Airplane Mode.
3. Create a spread, task, note, and event.
4. Open Debug menu > Sync section and confirm the outbox count increases.
5. Disable Airplane Mode.
6. Wait for auto-sync or trigger a manual sync.
7. Verify outbox count returns to 0 and the rows exist in Supabase.

### 2.2 Update Entities Offline, Then Sync

1. While online, create a task and wait for sync.
2. Enable Airplane Mode.
3. Edit the task title, status, and date.
4. Verify the outbox count increases.
5. Disable Airplane Mode and sync.
6. Verify the server row reflects the updated fields.

### 2.3 Pull Server Changes

1. Use Supabase SQL Editor to insert or update a task for the signed-in user.
2. Trigger sync by foregrounding the app or using Debug > Sync Now.
3. Verify the app reflects the server-side change.

### 2.4 Soft Delete From Server

1. Use SQL Editor to set `deleted_at = now()` for an existing task.
2. Trigger sync.
3. Verify the task disappears from the app.

## 3. Conflict Resolution

### 3.1 Field-Level Last-Write-Wins

1. Create a task and sync it.
2. Go offline and change the title locally.
3. On the server, update the same title with an older `title_updated_at`.
4. Reconnect and sync.
5. Verify the local title wins.

### 3.2 Delete Wins Over Update

1. Create a task and sync it.
2. Go offline and edit the task locally.
3. On the server, soft-delete the same task.
4. Reconnect and sync.
5. Verify the task is deleted.

### 3.3 Different Fields Merge

1. Create a task and sync it.
2. Go offline and change the title locally.
3. On the server, change the status.
4. Reconnect and sync.
5. Verify both changes are preserved.

## 4. Network Resilience

### 4.1 Retry After Failure

1. Sign in and begin a sync.
2. Force a failure with Airplane Mode or Debug sync overrides.
3. Verify sync shows an error and retries later.
4. Restore connectivity.
5. Verify a later retry succeeds.

### 4.2 Foreground Trigger

1. Background the app.
2. Make a server-side change.
3. Return the app to the foreground.
4. Verify sync runs and pulls the change.

### 4.3 Connectivity Restore Trigger

1. Go offline and make local edits.
2. Restore connectivity.
3. Verify sync starts automatically.

## 5. Debug Localhost Isolation

### 5.1 Localhost Bypasses Product Auth

1. Launch Debug with `-DataEnvironment localhost`.
2. Verify the app opens directly into journal content without the product auth gate.

### 5.2 Mock Data Loads Only In Localhost

1. Launch Debug with `-DataEnvironment localhost -MockDataSet baseline`.
2. Verify the mock data set loads.
3. Relaunch Debug without `localhost`.
4. Verify the mock data set is not loaded into the dev-backed run.

### 5.3 Localhost Transition Wipes Local Store

1. Launch Debug in `localhost` and load mock data.
2. Quit the app.
3. Relaunch Debug without `localhost`.
4. Verify the local store is wiped before the dev-backed run starts.

## 6. Local Supabase Durability Workflow

### 6.1 Local Supabase Bootstrap

1. Run `./scripts/local-supabase.sh start`.
2. Run `./scripts/local-supabase.sh reset`.
3. Verify `supabase/local/test.env` is generated.
4. Launch the app with local Supabase override arguments from `./scripts/local-supabase.sh launch-args`.

### 6.2 Rebuild From Local Server State

1. Launch the app against local Supabase and sign in with a deterministic local test account.
2. Create or migrate an entry and wait for sync.
3. Wipe the app locally or reinstall it.
4. Relaunch against the same local Supabase backend and sign in again.
5. Verify placement and history match exactly.

### 6.3 Sign Out / Sign In Recovery

1. Launch the app against local Supabase and sign in with a deterministic local test account.
2. Create, migrate, or reassign an entry and wait for sync.
3. Sign out so the local store is wiped.
4. Sign back into the same account.
5. Verify the same active placement and migrated/source-history state are restored from the server.

### 6.4 Clean Second-Client Reconstruction

1. Launch one client against local Supabase and sign in with a deterministic local test account.
2. Create, migrate, reassign, or delete a spread and wait for sync.
3. Launch a second clean client against the same local Supabase backend and sign into the same account.
4. Verify the second client reproduces the same placement and source-history UI.

### 6.5 Backfill Recovery

1. Prepare a local test entry whose local model contains assignment history while local Supabase has zero assignment rows for that entry.
2. Trigger sync.
3. Verify the app silently repairs the assignment rows.
4. Wipe local state and rebuild from local Supabase.
5. Verify the repaired history is preserved.

## 7. Debug Menu Verification

### 7.1 Sync Section

1. In a product environment, open Debug > Sync.
2. Verify status, outbox count, and last-sync information are visible.

### 7.2 Mock Data Section

1. Launch Debug in `localhost`.
2. Verify Debug shows a Mock Data Sets section.
3. Launch Debug in `development`.
4. Verify the Mock Data Sets section is absent.
