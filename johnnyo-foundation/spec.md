# johnnyo-foundation Spec

## Package Purpose

- Provide reusable components and utilities that can be shared across `Spread` and future apps.
- Keep package APIs generic and dependency-injected.
- Keep app-specific content generation, styling, and business rules out of the package.

## Target Layout

- `JohnnyOFoundationCore`
  - pure models, context types, helper algorithms, and non-UI protocols
- `JohnnyOFoundationUI`
  - SwiftUI components built on `JohnnyOFoundationCore`

## Documentation Requirements

- The package must ship with:
  - `README.md`
  - `spec.md`
  - package-local unit tests

## First Feature

- A reusable month calendar shell:
  - month header slot
  - weekday header row
  - date grid
  - configurable peripheral-date rendering
  - shell-owned month math and weekday ordering
  - injected content generator and optional action delegate

## Integration Boundary

- `Spread` should import only `JohnnyOFoundationUI`
- `Spread` supplies its own month-calendar content generator
- the first `Spread` integration is view-only
