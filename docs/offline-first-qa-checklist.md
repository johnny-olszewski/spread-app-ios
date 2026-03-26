# Offline-First Manual QA Checklist

Manual test plan for the simplified offline-first model. Product environments require authentication, while Debug `localhost` remains the engineering-only local mode.

## Scope Split

- Product environments: signed-in offline-first behavior with cached local data and sync recovery
- Debug `localhost`: local-only engineering workflow, mock auth, and mock data

## Prerequisites

- iOS device or simulator
- Debug build with Debug menu enabled
- Ability to toggle Airplane Mode
- Supabase Dashboard access for server-side verification
- One signed-in product-environment test account

## 1. Product Environments

### 1.1 Fresh Signed-Out Offline Launch

1. Ensure the app has no valid session.
2. Enable Airplane Mode.
3. Launch the app in a product environment.
4. Verify the auth gate is shown and journal content is not accessible.

### 1.2 Cached Session Offline Launch

1. Sign in while online.
2. Create or sync some data locally.
3. Force-quit the app.
4. Enable Airplane Mode.
5. Relaunch the app.
6. Verify previously cached data is visible and usable.

### 1.3 Offline Create and Edit

1. Sign in and wait for the app to finish syncing.
2. Enable Airplane Mode.
3. Create spreads, tasks, notes, events, and collections.
4. Edit several of those items.
5. Verify each change persists across navigation and relaunch while still offline.

### 1.4 Offline Delete

1. While signed in, create and sync a task and a note.
2. Enable Airplane Mode.
3. Delete them locally.
4. Verify they stay deleted after relaunch while still offline.

### 1.5 Reconnect and Sync

1. Stay signed in with pending offline edits.
2. Disable Airplane Mode.
3. Verify the outbox drains and server state matches the local changes.

### 1.6 Sign-Out While Offline

1. Go offline while signed in.
2. Use the profile sheet to sign out.
3. Confirm the sign-out warning.
4. Verify local data is wiped and the app returns to the auth gate.

### 1.7 Conventional Migration Prompt Scenarios

1. Set the simulator date to `January 12, 2026`.
2. In conventional mode, ensure spreads `2026` and `January 2026` exist but `January 10, 2026` does not.
3. Create a task with desired assignment `January 10, 2026` day while it is still assigned to `2026` or `January 2026`.
4. Verify `January 2026` shows the migration banner because it is the most granular valid existing destination.
5. Create spread `January 10, 2026`.
6. Verify the month spread no longer prompts that task and the day spread now shows the migration banner.

### 1.8 Desired-Assignment Boundaries

1. Set the simulator date to `January 12, 2026`.
2. Ensure spreads `2026`, `January 2026`, and `January 10, 2026` all exist.
3. Create a task whose desired assignment is `January 2026` month and whose current source is `2026`.
4. Verify `January 2026` shows the migration prompt for that task.
5. Verify `January 10, 2026` does not prompt for that task.

### 1.9 Global Overdue Review

1. Set the simulator date to `January 12, 2026`.
2. Create one open task assigned to `January 10, 2026` day and one open task assigned to `January 2026` month.
3. Verify the yellow overdue button appears with count `1` from both conventional and traditional spread surfaces.
4. Open the overdue review sheet and verify the day-assigned task appears while the month-assigned task does not.
5. Change the simulator date to `February 1, 2026`.
6. Verify the overdue button count increases to include the month-assigned task and the review sheet groups tasks by source assignment.

### 1.10 Traditional-Mode Behavior

1. Switch to traditional mode.
2. Verify the overdue button remains available when overdue tasks exist.
3. Navigate year -> month -> day and confirm no migration banner appears anywhere in traditional mode.

## 2. Conflict and Recovery

### 2.1 Local Edit Beats Older Server Edit

1. Sync a task.
2. Go offline and update the title locally.
3. Apply an older server-side title update.
4. Reconnect and sync.
5. Verify the local title wins.

### 2.2 Server Delete Beats Local Update

1. Sync a task.
2. Go offline and update it locally.
3. Soft-delete it on the server.
4. Reconnect and sync.
5. Verify the task is removed.

### 2.3 Force-Quit With Pending Outbox

1. Make offline edits while signed in.
2. Force-quit the app.
3. Relaunch while still offline and verify the edits remain.
4. Restore connectivity and verify sync completes.

## 3. Debug Localhost

### 3.1 Localhost Opens Without Product Auth

1. Launch Debug with `-DataEnvironment localhost`.
2. Verify the app opens directly into content using mock auth.

### 3.2 Mock Data Workflow

1. In localhost, load a mock data set from the Debug menu.
2. Verify the data appears immediately.
3. Quit and relaunch without `localhost`.
4. Verify the mock data does not appear in the dev-backed run.

### 3.3 Localhost Remains Local

1. In localhost, create and edit data while offline.
2. Verify no sync activity occurs and status remains local-only.
3. Relaunch in a product environment.
4. Verify the localhost store is wiped during the transition.

## 4. Reference Scenarios

Use these absolute-date scenarios when validating migration and overdue behavior:

| Today | Setup | Expected result |
| --- | --- | --- |
| `January 12, 2026` | Task desired `January 2026` month, current source `2026`, spreads `2026` + `January 2026` | `January 2026` prompts migration. |
| `January 12, 2026` | Task desired `January 10, 2026` day, current source `2026`, spreads `2026` + `January 2026` | `January 2026` prompts migration until the day spread exists. |
| `January 12, 2026` | Same task, now with `January 10, 2026` spread created | Only `January 10, 2026` prompts migration. |
| `January 12, 2026` | Task assigned to `January 10, 2026` day | Task is overdue. |
| `January 12, 2026` | Task assigned to `January 2026` month | Task is not overdue yet. |
| `February 1, 2026` | Task assigned to `January 2026` month | Task is overdue. |
| `February 1, 2026` | Inbox task desired for `January 2026` month | Task is overdue via Inbox fallback. |
