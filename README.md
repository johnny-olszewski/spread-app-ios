# Spread

A SwiftUI bullet journal (BuJo) app for iOS 26+ using SwiftData for persistence with iCloud sync.

## Getting Started

### Requirements

- Xcode 17+
- iOS 26+ / iPadOS 26+

### Building

```bash
# Build the project
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## App Environments

Spread supports multiple execution environments to facilitate development, testing, and production use. The environment affects storage behavior, mock data usage, and container isolation.

### Environment Types

| Environment   | Storage         | Mock Data | Use Case                        |
|---------------|-----------------|-----------|--------------------------------|
| `production`  | Persistent      | No        | App Store / TestFlight releases |
| `development` | Persistent      | No        | Local development with real data |
| `preview`     | In-memory only  | Yes       | SwiftUI previews               |
| `testing`     | In-memory only  | No        | Unit and integration tests     |

### How Environments Are Resolved

The app determines the current environment in this order:

1. **Launch Arguments**: Pass `-AppEnvironment <value>` (e.g., `-AppEnvironment development`)
2. **Environment Variables**: Set `APP_ENVIRONMENT=<value>`
3. **Build Configuration**: Defaults to `development` for DEBUG builds, `production` for Release

### Setting Environment in Xcode

1. Edit your scheme (Product → Scheme → Edit Scheme)
2. Select "Run" → "Arguments"
3. Add launch argument: `-AppEnvironment development`

Or add an environment variable:
- Name: `APP_ENVIRONMENT`
- Value: `development` (or `preview`, `testing`)

## Debug Menu & Mock Data Sets

In DEBUG builds, a **Debug** tab (iPhone) or sidebar item (iPad) provides development tools.

### Mock Data Sets

The Debug menu includes predefined mock data sets for testing different scenarios. **Loading a data set overwrites all existing data.**

| Data Set         | Description                                              |
|------------------|----------------------------------------------------------|
| **Empty**        | Clears all spreads, tasks, events, and notes             |
| **Baseline**     | Year, month, and day spreads for today with sample entries |
| **Multiday Ranges** | Multiday spreads using presets (This Week, Next Week) and custom ranges |
| **Boundary Dates** | Spreads across month and year boundaries for edge case testing |
| **High Volume**  | 50+ spreads and 100+ tasks for performance testing       |

### Using Mock Data Sets

1. Navigate to the Debug tab/sidebar
2. Scroll to the "Mock Data Sets" section
3. Tap the desired data set
4. Confirm the success alert

**Note**: Loading a data set will:
- Delete all existing spreads, tasks, events, and notes
- Insert the generated test data
- Trigger a data reload

### How Mock Data Sets Work with Environments

Mock data sets operate on the repositories configured for the current environment:

- **Production/Development**: Data is persisted to disk via SwiftData. Changes survive app restarts.
- **Preview/Testing**: Data is stored in-memory only. Changes are lost when the app terminates.

**Recommendation**: Use the `development` environment when testing mock data sets to ensure data persists between debugging sessions.

## Testing

### Running Tests

```bash
# Run all tests
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run a specific test
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SpreadTests/MockDataSetTests test
```

### Test Environment

Tests run in the `testing` environment by default:
- **In-memory storage**: Tests start with a clean slate
- **No mock data**: Tests explicitly set up their own fixtures
- **Isolated containers**: Each test can use fresh repositories

### Writing Tests

Tests use Swift Testing framework. Example:

```swift
@Test("Loading empty data set clears all data")
@MainActor
func loadingEmptyClears() async throws {
    let taskRepo = InMemoryTaskRepository(tasks: TestData.sampleTasks())
    // ... test implementation
}
```

Test files should include comments describing:
- The conditions/setup being tested
- The expected results/behavior

### Test Data Helpers

The `TestData` enum provides sample data for previews and tests:

```swift
let sampleTasks = TestData.sampleTasks()
let sampleSpreads = TestData.sampleSpreads()
let sampleEvents = TestData.sampleEvents()
let sampleNotes = TestData.sampleNotes()
```

## Architecture

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation, code style guide, and development instructions.

## License

Copyright 2026. All rights reserved.
