# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run a single test
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SpreadTests/SpreadTests/testFunctionName test
```

## Project Overview

Spread is a SwiftUI bullet journal (BuJo) app for iOS 26+ using SwiftData for local persistence with Supabase sync.

### Source of Truth

- `spec.md` - Product specification and requirements
- `plan.md` - Implementation plan with task definitions (SPRD-# format)

## Architecture Overview

### Core Concepts

**Spreads**: Journaling pages tied to time periods. Supported periods: `year`, `month`, `day`, `multiday`. Week period is NOT supported.

**Entries**: Parent protocol for all journal items. Three concrete types:
- `Task` - Assignable entry with status (open, complete, migrated, cancelled) and migration history
- `Event` - Date-range entry with computed visibility (no assignments)
- `Note` - Assignable entry with extended content, explicit-only migration

**Assignments**: Track per-spread status for tasks (`TaskAssignment`) and notes (`NoteAssignment`). Events have no assignments - visibility is computed from date range overlap.

**Modes**:
- Conventional: Tab-based spreads, migration history visible, entries on multiple spreads
- Traditional: Calendar navigation (year → month → day), entries on preferred date only

### Key Patterns

- `Entry` protocol with `AssignableEntry` and `DateRangeEntry` sub-protocols
- Extensions namespace data models under `DataModel` struct (e.g., `DataModel.Task`, `DataModel.Spread`)
- Repository pattern for persistence (`TaskRepository`, `SpreadRepository`, `EventRepository`, `NoteRepository`)
- `JournalManager` as central coordinator for spreads, entries, and business logic
- `DependencyContainer` for dependency injection with environment-specific configurations
- `EntryListView` is a pure row renderer — no `ScrollView`, no background chrome. Scroll and visual containment belong to the caller.

### Folder Structure

```
Spread/
├── App/                    # App entry point, scenes
├── DataModel/              # SwiftData models, protocols
├── Repositories/           # Repository protocols + implementations
├── Services/               # Business logic services
├── JournalManager/         # Core coordinator
├── Environment/            # AppEnvironment, DependencyContainer
├── Views/                  # SwiftUI views organized by feature
│   ├── Navigation/
│   ├── Spreads/
│   ├── Entries/
│   ├── Settings/
│   └── Components/
└── Additions/              # Extensions, utilities
SpreadTests/                # Swift Testing tests (mirrors source structure)
```

## Architecture Decisions

### Testability

- **Protocols at boundaries**: Introduce protocols at dependency injection points (services, repositories, coordinators) to enable test substitution. Simple value types, helpers, and internal logic stay concrete.
- **Manual mocks**: Hand-written mock types conforming to protocols. Each mock lives in its own file (`MockTypeName.swift`). No code-generation or spy frameworks.
- **`Test*`/`Mock*` prefix any type that is exclusively non-production**: A type used only by unit tests, SwiftUI previews, and/or the debug/localhost runtime — never by the production dependency graph — must be prefixed `Test` or `Mock`, chosen by behavior:
  - **`Mock*`**: tracks calls, records invocations, or injects errors/failures for assertion (e.g. `MockAuthService`, `MockNetworkMonitor`).
  - **`Test*`**: a plain stand-in with no call-tracking — just enough behavior to be a working substitute (e.g. an in-memory dictionary-backed repository).
  - Both live in the main target alongside the real implementation (not under `Debug/`).
- **Structs by default**: Prefer structs for services, coordinators, and data types. Use classes only when identity semantics are required (`@Observable`, SwiftData `@Model`, or shared mutable state).
- **No singletons**: Avoid `static let shared` singletons. Prefer init-injected dependencies so that tests can substitute implementations without global state coupling.

### Separation of Concerns

- **Minimize `#if DEBUG` in production files**: Debug-only code (mock decorators, debug services, test helpers) must live in dedicated files under the `Debug/` folder or as `TypeName+Debug.swift` extensions. Production source files must not contain `#if DEBUG` blocks to the maximum extent practical. Shim files that use `#if DEBUG` solely for typealias configuration (e.g., switching factory types between debug and release) are acceptable.
- **Extensions per conformance**: Each protocol conformance gets its own extension, in a separate file when non-trivial (e.g., `TypeName+Codable.swift`, `TypeName+CustomStringConvertible.swift`).
- **Single responsibility for new types**: Extract a new coordinator or service when it has a distinct lifecycle, distinct dependencies, or the existing type exceeds ~200 lines. Prefer composition over growing existing types.
- **No namespace enums as factory containers**: Don't create an enum with no cases (e.g., `enum FooSupport {}`) just to hold static factory methods. Factory/init logic belongs directly on the type being constructed as `init` or `static func` members (e.g., `SpreadCardStyle.init(for:today:explicitDaySpread:calendar:)` not `FooSupport.cardStyle(...)`). Namespace enums used this way are a sign the logic should be promoted to the target type.

### View Coordinators

- **When to use**: Introduce a coordinator for a view when it manages 3+ presentation states (sheets, alerts, navigation) or when child views thread callbacks to trigger parent presentations. Simple single-sheet views do not need a coordinator.
- **Shape**: `@Observable @MainActor final class FeatureCoordinator`. Owns presentation state and action methods. Does **not** contain `@ViewBuilder` methods — views construct their own sheet content.
- **Sheet state as enum**: Use a single `activeSheet: SheetDestination?` with an `Identifiable` enum instead of multiple booleans. Use `.sheet(item:)` binding. This guarantees only one sheet at a time and scales as sheets are added.
- **Dependencies stay on views**: Coordinators own only presentation state and actions. Dependencies (`JournalManager`, `AuthManager`, etc.) continue to be init-injected into views. The coordinator is not a service locator.
- **Child view interaction**: Child views receive the coordinator and call action methods (e.g., `coordinator.showTaskCreation()`) instead of receiving closure callbacks.
- **Stored in `@State`**: The parent view that creates the coordinator stores it in `@State` and passes it to children.
- **No local sheet state in content views**: Spread content views (`DaySpreadContentView`, `MultidaySpreadContentView`, etc.) must not declare `@State` sheet variables. All sheet presentation goes through `SpreadsCoordinator.activeSheet`. Before adding any sheet-triggering state to a content view, check whether a `coordinator.showXxx()` method already exists.

### Concurrency (Swift 6 Strict)

- **`@MainActor`-first**: Default to `@MainActor` for services, coordinators, managers, and any type that touches UI state. Only opt out with `nonisolated` when a method provably does no UI work and benefits from running off-main.
- **Sendable — compiler-driven**: Let the compiler enforce `Sendable`. Structs with all-Sendable properties are automatically Sendable. Add explicit conformance only when the compiler requires it at isolation boundaries. Never use `@unchecked Sendable` without a documented justification comment.
- **Structured concurrency preferred**: Use `async`/`await`, `async let`, and `TaskGroup` for concurrent work. Use unstructured `Task {}` only at sync-to-async boundaries (SwiftUI `.task`, button actions). Never fire-and-forget — unstructured `Task`s must be stored or awaited.
- **Isolation boundary awareness**: When passing closures or values across isolation boundaries, ensure they are `Sendable`. Prefer value types at boundaries to avoid accidental shared mutable state.

### Scroll Management

- **Single decision point**: `SpreadContentPagerView` is the sole place where vertical scroll is applied, via `.conditionalScrollView()` on `contentView(for:)`. This keeps the header (`SpreadHeaderView`) pinned while the spread content scrolls.
- **Content views own no scroll**: `YearSpreadContentView`, `MonthSpreadContentView`, `DaySpreadContentView`, and `MultidaySpreadContentView` do not own a `ScrollView`. If a content view needs programmatic scroll (e.g., `ScrollViewReader`), the reader wraps the content directly and the outer `ScrollView` is provided by the pager.
- **`EntryListView` owns no scroll**: See Key Patterns above.

### Behavior

- **Ask, don't assume**: When requirements are ambiguous or an architectural decision could go multiple ways (new protocols, new files, dependency patterns), ask for clarification before proceeding. Follow established patterns autonomously for routine implementation.
- **Pros/cons for decisions**: When presenting options, provide pros and cons and a recommendation for each.
- **Check for redundancy before implementing**: Before adding new logic (helpers, computed properties, extensions, view models), search for existing code that already does something similar — including the same logic duplicated across files. Prefer extending or sharing existing implementations (e.g., promoting a duplicated helper to a shared protocol extension) over adding a new, parallel one.
- **Prefer first-class APIs over wrapper closures**: Before adding a closure parameter or computed property to derive data, verify `JournalManager` (or another existing service) doesn't already expose it directly. E.g., `journalManager.spreadDataModel(for:period:)?.spread` is the first-class lookup — wrapping it in a closure on the view adds indirection with no benefit.
- **Two elements over one conditional element**: When a button or UI element has meaningfully different label, icon, and action depending on state, use two distinct elements with an `if/else` rather than a single element with conditional content. This makes SwiftUI animations work correctly and the intent clearer.
- **Delete production code with no production caller**: If a type or method in the main target has zero callers outside test files (including when it's only kept alive as a "legacy baseline" for a parity test against newer code), delete it rather than leaving it as dead weight — Debug-only call sites (under `Debug/`, gated by `#if DEBUG`) count as real callers, test-only call sites do not. Before deleting, check whether any test exercises real behavior solely through the dead code with no equivalent coverage elsewhere; if so, port that behavior assertion to a still-live call path (or delete the test if the behavior is already covered) rather than leaving a parity test comparing against nothing.

## Session Workflow

Sessions are the primary unit of work. A session branch (`feature/SESH-##`) bundles multiple related SPRD-## tasks completed over a short period (typically a few days). One PR is created per session branch. Tasks are distinguished within the branch by their commit messages.

### Starting a Session

1. Check git status — confirm you are on the correct `feature/SESH-##` branch, or create one.
2. Read `Documentation/Specs/_index.md` to find the relevant per-feature spec file(s).
3. Load the specific spec file for the active task — do not load the full `Documentation/spec.md` monolith.
4. Read the task's `SPRD-##` block in `Documentation/plan.md` for acceptance criteria.
5. Read `Documentation/backlog.md` only when reprioritizing or scoping new work.

### Speccing a New Task with AI

When the user has no ready task and wants to spec one out:
1. User describes the feature idea in conversation.
2. Read the relevant spec file(s) from `Documentation/Specs/` to understand current state and decisions.
3. Draft spec additions or changes to the appropriate `Documentation/Specs/FeatureName.md`, following the template in `Documentation/Specs/_template.md`.
4. Create a new `SPRD-##` block in `Documentation/plan.md` using the task template.
5. Commit spec and plan changes on the current SESH branch as `[SESH-##][1/n] spec: FeatureName`.

## Task Workflow

- Before starting a task, read its acceptance criteria in `Documentation/plan.md`
- Load the spec file linked in the task's `Spec:` field from `Documentation/Specs/`
- Check what's already implemented in the codebase against each AC
- Flag gaps, ambiguities, or already-satisfied ACs before writing code
- After completing a task, update its status in `Documentation/plan.md`

## Git and Version Control

- The priority for versioning, in addition to preventing bugs, should be to ease review by strategically making changes.
- **Session branches** are the primary branch type: `feature/SESH-##` (incrementing integer, e.g. `feature/SESH-21`). They bundle multiple related SPRD-## tasks and result in one PR.
- Task branches are not created per-task; tasks are completed on the active session branch.
- Strive to break changes into small logical commits. All changes per commit should be related.
- Commits should be stable.
- Commit messages follow the format: `[SPRD-#][#/n] brief message with high level change description`
- Spec/plan-only commits that kick off a new task use the format: `[SESH-##][#/n] spec: FeatureName`
- Use `n` explicitly in all commit messages — the total commit count is not known in advance

## Code Style Guide

### Organization

- **Access control**: Minimal - only add modifiers when restricting access
- **Member organization**: Organize by type (properties, initializers, methods) with `// MARK: -` sections
- **Property wrapper grouping**: Group by wrapper type (`@Environment` together, `@State` together, etc.)
- **One type per file**: Match filename to type name exactly (except extensions)
- **Extensions**: Separate files by default (`TypeName+Feature.swift`), same file okay for small protocol conformances

### Naming

- **Booleans**: Use `is`/`has`/`can` prefix (e.g., `isLoading`, `hasError`, `canSubmit`)
- **Test names**: Use descriptive phrases (e.g., `testMigrationUpdatesAssignmentStatus`)

### Syntax Preferences

- **Trailing closures**: Use when there's only one closure
- **Closure parameters**: Explicit names when multi-reference or multi-line, `$0` okay for single-reference single-line
- **Self reference**: Only when required (disambiguation, closures)
- **Optionals**: Guard early (`guard let x else { return }`), others where applicable
- **Line length**: 120 characters max, break multi-line at 3+ parameters

### SwiftUI Views

- **Subview extraction**: Computed properties for subviews, methods when injection required
- **Previews**: Every view includes previews; component previews should have multiple examples
- **Observable access**: Direct property access on `@Observable` classes
- **Size class over device idiom**: When the user refers to "iPad UI" or "iOS UI" layout differences, implement them using `@Environment(\.horizontalSizeClass)` (`compact` vs `regular`) rather than platform or device-idiom checks. Use `UIDevice.current.userInterfaceIdiom` or `#if os(iOS)` only for functionality that is genuinely device- or OS-specific (e.g., a hardware API unavailable on one platform). Ask for clarification when it is unclear which applies.
- **Inject `horizontalSizeClass` into spread content views**: `DaySpreadContentView` and `MultidaySpreadContentView` receive `horizontalSizeClass: UserInterfaceSizeClass?` via `init` from `SpreadContentPagerView`, which reads `@Environment(\.horizontalSizeClass)`. Content views do not read it via `@Environment` themselves — this prevents repeated environment subscriptions and keeps the pager as the layout authority.
- **Layout helpers belong on existing types**: Simple layout values derived from a single type belong as an extension on that type (e.g., `UserInterfaceSizeClass.multidayColumnCount`), not in a dedicated helper enum or namespace struct.
- **No wrapper private structs without a real boundary**: Avoid extracting a private sub-struct inside a view solely to regroup its `body`. If the type doesn't introduce new properties, lifecycle, or dependencies, inline the content instead.

### Patterns

- **Error handling**: Typed errors (custom enums per domain), throwing for sync, Result/async throws for async
- **Constants**: Enum namespaces (e.g., `enum Constants { static let timeout = 30 }`)
- **Async/MainActor**: See [Concurrency (Swift 6 Strict)](#concurrency-swift-6-strict) in Architecture Decisions
- **Dependency injection**: Environment for app-wide (JournalManager), init injection for view-specific
- **Logging**: Use OSLog/Logger

### Imports

- **Foundation**: Prefer `import Foundation` over selective imports (`import struct Foundation.UUID`). Selective imports add noise and break easily when new Foundation types are used.
- **Grouped**: System frameworks first, then third-party, then local modules

### Documentation

- **Doc comments**: Liberal use of `///` documentation comments on members
- **Inline comments**: Avoid - code should be self-documenting; use only when truly necessary to explain "why"
- **TODO comments for known planned changes**: If you know that code you're writing will change because of a task that already exists as a `SPRD-##` block in `Documentation/plan.md`, add a `- TODO: [SPRD-##] <one-line description>` line in the doc comment at the relevant type/method, naming the task and what's expected to change. This lets a reviewer see the change is coming and isn't an oversight. Only add these for changes with a real, already-scoped task — not speculative ideas with no tracked task.

### Testing (Swift Testing)

- **Test names**: Descriptive phrases
- **Test documentation**: Each test must include a comment above it describing:
  - The conditions/setup being tested
  - The expected results/behavior
- **Assertions**: Multiple related assertions per test allowed
- **Test structure**: Mirror source folder structure in test folder

## Deferred Decisions

- **Localization**: Hardcoded English strings for v1. Revisit localization strategy post-v1.
