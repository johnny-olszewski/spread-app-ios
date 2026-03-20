# Offline-First Manual QA Checklist

Manual test plan for validating offline-first behavior and sync reconciliation. This checklist covers the core user flows that must work reliably without network connectivity.

## Prerequisites

- iOS device or simulator
- Debug build with Debug menu enabled
- Ability to toggle Airplane Mode (or use Debug menu network controls)
- Supabase Dashboard access for server-side verification
- Two devices (or simulator + device) for multi-device scenarios

---

## 1. Offline Create Operations

### 1.1 Create Spread Offline

1. Enable Airplane Mode.
2. Create a new Day spread for today.
3. Verify the spread appears in the spread list immediately.
4. Navigate away and back — confirm persistence.
5. Force-quit and relaunch — confirm the spread still exists.

### 1.2 Create Task Offline

1. Enable Airplane Mode.
2. Open a spread and create a new task with title "Offline Task".
3. Verify the task appears in the entry list.
4. Set the task status to complete.
5. Verify the status change persists after navigating away.

### 1.3 Create Event Offline

1. Enable Airplane Mode.
2. Create an event with a date range spanning 3 days.
3. Verify the event appears on all relevant day/month spreads within its range.

### 1.4 Create Note Offline

1. Enable Airplane Mode.
2. Create a note with a title and extended content.
3. Verify the note appears in the spread's entry list.
4. Edit the note's content — confirm edits persist locally.

### 1.5 Create Collection Offline

1. Enable Airplane Mode.
2. Create a new collection with title and body text.
3. Navigate to the collections list — confirm it appears.
4. Edit the collection — confirm edits persist.

---

## 2. Offline Edit Operations

### 2.1 Edit Task Title Offline

1. While online, create a task "Original Title" and wait for sync.
2. Enable Airplane Mode.
3. Edit the title to "Updated Title".
4. Verify the new title displays everywhere the task appears.

### 2.2 Edit Task Status Offline

1. While online, create an open task.
2. Enable Airplane Mode.
3. Toggle the task to complete.
4. Verify the checkmark/status icon updates immediately.
5. Toggle back to open — verify it reverts.

### 2.3 Edit Task Date Offline

1. Enable Airplane Mode.
2. Change a task's date from today to tomorrow.
3. Verify the task moves to the correct spread.
4. Check the original spread no longer shows the task (if single-assignment mode).

### 2.4 Edit Note Content Offline

1. Enable Airplane Mode.
2. Open a note and edit its extended content (add paragraphs).
3. Navigate away and back — confirm the content is saved.

### 2.5 Edit Settings Offline

1. Enable Airplane Mode.
2. Change BuJo mode from Conventional to Traditional (or vice versa).
3. Verify the navigation changes immediately.
4. Force-quit and relaunch — confirm the setting persisted.

---

## 3. Offline Delete Operations

### 3.1 Delete Task Offline

1. While online, create a task and wait for sync.
2. Enable Airplane Mode.
3. Delete the task.
4. Verify the task disappears from all spreads.
5. Force-quit and relaunch — confirm the task is gone.

### 3.2 Delete Note Offline

1. Enable Airplane Mode.
2. Delete a note.
3. Verify it disappears immediately.

### 3.3 Delete Spread Offline

1. Enable Airplane Mode.
2. Delete a spread.
3. Verify it disappears from the spread list.
4. Entries that were only on that spread should still exist (they are not cascade-deleted locally).

---

## 4. Sync When Coming Back Online

### 4.1 Push After Offline Session

1. Enable Airplane Mode.
2. Perform several operations: create 2 tasks, edit 1, delete 1.
3. Open Debug menu — check outbox count (should be > 0).
4. Disable Airplane Mode.
5. Wait for auto-sync (or trigger manually).
6. Verify outbox count drops to 0.
7. Check Supabase Dashboard — all operations reflected on server.

### 4.2 Pull After Server Changes

1. While device is online and idle, use Supabase SQL Editor to insert a new task for the test user.
2. Trigger a sync (background or foreground the app).
3. Verify the new task appears on the device.

### 4.3 Bidirectional Sync

1. Make local edits offline (task title change).
2. Make server-side edits via SQL (different task's status change).
3. Reconnect.
4. Verify both changes are applied: local title pushed, server status pulled.

---

## 5. Conflict Resolution Behavior

### 5.1 Same Field, Local Wins (Newer Timestamp)

1. Create a task "Base Title" and sync.
2. Go offline. Change title to "Local Title".
3. Via SQL, change the same task's title to "Server Title" with an older `title_updated_at`.
4. Reconnect and sync.
5. **Expected**: Title is "Local Title" (local timestamp is newer).

### 5.2 Same Field, Server Wins (Newer Timestamp)

1. Create a task and sync.
2. Go offline. Change the title.
3. Wait a few seconds, then via SQL update the same title with a newer `title_updated_at`.
4. Reconnect and sync.
5. **Expected**: Server title wins (server timestamp is newer).

### 5.3 Different Fields Merge

1. Create a task and sync.
2. Go offline. Change the title locally.
3. Via SQL, change the status on the server.
4. Reconnect and sync.
5. **Expected**: Both changes applied — local title and server status merged.

### 5.4 Delete Wins Over Update

1. Create a task and sync.
2. Go offline. Edit the task's title.
3. Via SQL, soft-delete the task (set `deleted_at = now()`).
4. Reconnect and sync.
5. **Expected**: Task is deleted. Delete-wins policy overrides the local edit.

---

## 6. Multi-Device Sync Scenarios

### 6.1 Create on Device A, See on Device B

1. On Device A, create a task and wait for sync.
2. On Device B, trigger sync (or wait for auto-sync).
3. Verify the task appears on Device B with correct data.

### 6.2 Edit on Device A, Reflected on Device B

1. On Device A, edit a task title.
2. On Device B, trigger sync.
3. Verify Device B shows the updated title.

### 6.3 Delete on Device A, Removed on Device B

1. On Device A, delete a task.
2. On Device B, trigger sync.
3. Verify the task is removed from Device B.

### 6.4 Simultaneous Edits on Different Fields

1. On Device A (offline), change a task's title.
2. On Device B (offline), change the same task's status.
3. Reconnect Device A first — sync completes.
4. Reconnect Device B — sync completes.
5. **Expected**: Both devices end up with the merged result (Device A's title + Device B's status).

### 6.5 Simultaneous Edits on Same Field

1. On Device A (offline), change title to "A Edit" at time T1.
2. On Device B (offline), change title to "B Edit" at time T2 (T2 > T1).
3. Sync both devices.
4. **Expected**: Title is "B Edit" on both (newer timestamp wins).

---

## 7. App Lifecycle

### 7.1 Force-Quit With Pending Outbox

1. Make edits offline (outbox > 0).
2. Force-quit the app.
3. Relaunch with network available.
4. Verify outbox mutations are still present and sync completes.

### 7.2 Background and Resume

1. Make edits, sync completes.
2. Background the app.
3. Make a server-side change via SQL.
4. Bring app to foreground.
5. Verify auto-sync pulls the server change.

### 7.3 Extended Offline Period

1. Go offline.
2. Use the app extensively: create spreads, tasks, notes, events, edit many items.
3. Force-quit and relaunch (still offline) — verify all data persisted.
4. Come back online.
5. Verify all accumulated mutations sync successfully in one batch.

---

## 8. Edge Cases

### 8.1 No Network on Fresh Install

1. Install app with Airplane Mode enabled.
2. Create entries.
3. Verify the app is fully functional (local SwiftData).
4. Sign in when network becomes available.
5. Verify local data syncs.

### 8.2 Sign Out While Offline With Pending Outbox

1. Go offline and make edits.
2. Sign out.
3. **Expected**: Warning about local data wipe. After confirmation, data cleared.
4. Sign back in online.
5. **Expected**: Only server data remains (local edits from before sign-out are lost).

### 8.3 Network Drops Mid-Sync

1. Start a sync with a large outbox.
2. Kill network mid-sync (Airplane Mode).
3. **Expected**: Sync fails gracefully. Status shows error. Unsent mutations remain in outbox.
4. Reconnect.
5. **Expected**: Retry succeeds. Remaining mutations are pushed.

---

## Pass/Fail Summary

| Section | Scenario | Result |
|---------|----------|--------|
| 1.1 | Create Spread Offline | |
| 1.2 | Create Task Offline | |
| 1.3 | Create Event Offline | |
| 1.4 | Create Note Offline | |
| 1.5 | Create Collection Offline | |
| 2.1 | Edit Task Title Offline | |
| 2.2 | Edit Task Status Offline | |
| 2.3 | Edit Task Date Offline | |
| 2.4 | Edit Note Content Offline | |
| 2.5 | Edit Settings Offline | |
| 3.1 | Delete Task Offline | |
| 3.2 | Delete Note Offline | |
| 3.3 | Delete Spread Offline | |
| 4.1 | Push After Offline Session | |
| 4.2 | Pull After Server Changes | |
| 4.3 | Bidirectional Sync | |
| 5.1 | Local Wins (Newer) | |
| 5.2 | Server Wins (Newer) | |
| 5.3 | Different Fields Merge | |
| 5.4 | Delete Wins Over Update | |
| 6.1 | Create A → See B | |
| 6.2 | Edit A → See B | |
| 6.3 | Delete A → Remove B | |
| 6.4 | Simultaneous Different Fields | |
| 6.5 | Simultaneous Same Field | |
| 7.1 | Force-Quit With Outbox | |
| 7.2 | Background and Resume | |
| 7.3 | Extended Offline Period | |
| 8.1 | No Network on Fresh Install | |
| 8.2 | Sign Out Offline + Outbox | |
| 8.3 | Network Drops Mid-Sync | |
