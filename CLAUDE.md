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

## Git and Version Control

- Tasks should begin by creating a branch for the specific task
- Task branches should be named by their task number (e.g., `SPRD-42`)
- Incremental changes that can be logically grouped together should be committed together to make review easier
- Commit messages should follow the format: `[SPRD-#][#/n] brief message with high level change description`

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
- **Async/MainActor**: `@MainActor` by default for managers and view models
- **Dependency injection**: Environment for app-wide (JournalManager), init injection for view-specific
- **Logging**: Use OSLog/Logger

### Imports

- **Minimal**: Only import what's needed (prefer `import struct Foundation.UUID` over `import Foundation` when applicable)
- **Grouped**: System frameworks first, then third-party, then local modules

### Documentation

- **Doc comments**: Liberal use of `///` documentation comments on members
- **Inline comments**: Avoid - code should be self-documenting; use only when truly necessary to explain "why"

### Testing (Swift Testing)

- **Test names**: Descriptive phrases
- **Assertions**: Multiple related assertions per test allowed
- **Test structure**: Mirror source folder structure in test folder

## Deferred Decisions

- **Localization**: Hardcoded English strings for v1. Revisit localization strategy post-v1.
