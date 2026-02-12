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

Spread is a SwiftUI bullet journal (BuJo) app for iOS 26+ using SwiftData for persistence with iCloud sync.

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
- **Structs by default**: Prefer structs for services, coordinators, and data types. Use classes only when identity semantics are required (`@Observable`, SwiftData `@Model`, or shared mutable state).
- **No singletons**: Avoid `static let shared` singletons. Prefer init-injected dependencies so that tests can substitute implementations without global state coupling.

### Separation of Concerns

- **Minimize `#if DEBUG` in production files**: Debug-only code (mock decorators, debug services, test helpers) must live in dedicated files under the `Debug/` folder or as `TypeName+Debug.swift` extensions. Production source files must not contain `#if DEBUG` blocks to the maximum extent practical. Shim files that use `#if DEBUG` solely for typealias configuration (e.g., switching factory types between debug and release) are acceptable.
- **Extensions per conformance**: Each protocol conformance gets its own extension, in a separate file when non-trivial (e.g., `TypeName+Codable.swift`, `TypeName+CustomStringConvertible.swift`).
- **Single responsibility for new types**: Extract a new coordinator or service when it has a distinct lifecycle, distinct dependencies, or the existing type exceeds ~200 lines. Prefer composition over growing existing types.

### View Coordinators

- **When to use**: Introduce a coordinator for a view when it manages 3+ presentation states (sheets, alerts, navigation) or when child views thread callbacks to trigger parent presentations. Simple single-sheet views do not need a coordinator.
- **Shape**: `@Observable @MainActor final class FeatureCoordinator`. Owns presentation state and action methods. Does **not** contain `@ViewBuilder` methods — views construct their own sheet content.
- **Sheet state as enum**: Use a single `activeSheet: SheetDestination?` with an `Identifiable` enum instead of multiple booleans. Use `.sheet(item:)` binding. This guarantees only one sheet at a time and scales as sheets are added.
- **Dependencies stay on views**: Coordinators own only presentation state and actions. Dependencies (`JournalManager`, `AuthManager`, etc.) continue to be init-injected into views. The coordinator is not a service locator.
- **Child view interaction**: Child views receive the coordinator and call action methods (e.g., `coordinator.showTaskCreation()`) instead of receiving closure callbacks.
- **Stored in `@State`**: The parent view that creates the coordinator stores it in `@State` and passes it to children.

### Concurrency (Swift 6 Strict)

- **`@MainActor`-first**: Default to `@MainActor` for services, coordinators, managers, and any type that touches UI state. Only opt out with `nonisolated` when a method provably does no UI work and benefits from running off-main.
- **Sendable — compiler-driven**: Let the compiler enforce `Sendable`. Structs with all-Sendable properties are automatically Sendable. Add explicit conformance only when the compiler requires it at isolation boundaries. Never use `@unchecked Sendable` without a documented justification comment.
- **Structured concurrency preferred**: Use `async`/`await`, `async let`, and `TaskGroup` for concurrent work. Use unstructured `Task {}` only at sync-to-async boundaries (SwiftUI `.task`, button actions). Never fire-and-forget — unstructured `Task`s must be stored or awaited.
- **Isolation boundary awareness**: When passing closures or values across isolation boundaries, ensure they are `Sendable`. Prefer value types at boundaries to avoid accidental shared mutable state.

### Behavior

- **Ask, don't assume**: When requirements are ambiguous or an architectural decision could go multiple ways (new protocols, new files, dependency patterns), ask for clarification before proceeding. Follow established patterns autonomously for routine implementation.
- **Pros/cons for decisions**: When presenting options, provide pros and cons and a recommendation for each.

## Task Workflow

- Before starting a task, read its acceptance criteria in `plan.md`
- Check what's already implemented in the codebase against each AC
- Flag gaps, ambiguities, or already-satisfied ACs before writing code
- After completing a task, update its status in `plan.md`

## Git and Version Control

- The priority for versioning, in addition to preventing bugs, should be to ease review by strategically making changes.
- Tasks should begin by creating a branch for the specific task
- Task branches should be named by their task number (e.g., `SPRD-42`)
- Task branches should be prefixed by `/feature`
- Strive to break changes into small logical commits. All changes per commit should be related. 
- Commits should be stable.
- Commit messages should follow the format: `[SPRD-#][#/n] brief message with high level change description`
- ensure that commit message use 'n' explicitly because we don't know how many commits there will be in this branch

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

### Testing (Swift Testing)

- **Test names**: Descriptive phrases
- **Test documentation**: Each test must include a comment above it describing:
  - The conditions/setup being tested
  - The expected results/behavior
- **Assertions**: Multiple related assertions per test allowed
- **Test structure**: Mirror source folder structure in test folder

## Deferred Decisions

- **Localization**: Hardcoded English strings for v1. Revisit localization strategy post-v1.
