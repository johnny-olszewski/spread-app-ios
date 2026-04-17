# johnnyo-foundation

`johnnyo-foundation` is the local Swift Package that holds reusable UI components and utilities extracted from `Spread`.

## Goals

- create a clean package boundary inside the app repo
- keep app-specific rendering and business rules out of shared components
- publish the package independently later with minimal restructuring

## Initial Structure

- `JohnnyOFoundationCore`
  - non-UI models, helpers, and algorithms
- `JohnnyOFoundationUI`
  - SwiftUI components built on the core target

The app should import only `JohnnyOFoundationUI` for UI use cases. That target depends on `JohnnyOFoundationCore` internally.

## Initial Scope

The first package feature is a reusable month calendar shell. The app provides `Spread`-specific content generation and embeds the month calendar inside month spread surfaces above the existing entry list.

## Month Calendar

The month calendar package surface is split intentionally:

- `JohnnyOFoundationCore`
  - month-grid generation
  - weekday ordering
  - peripheral-date handling
  - semantic context models
  - optional action-delegate protocol
- `JohnnyOFoundationUI`
  - `CalendarContentGenerator`
  - `MonthCalendarView`

The shell owns structure. Callers inject content for:

- month header
- weekday headers
- day cells
- placeholder cells when peripheral dates are hidden
- per-week background content for span-style rendering

## Package Documentation

- package product and architecture requirements live in [`spec.md`](./spec.md)
- package-local behavior is covered by package unit tests

## Status

- local package scaffolded inside the `Spread` repo
- ready for month calendar implementation
