//
//  SpreadTab.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

// MARK: - Design Constants

/// Centralized design constants for folder tabs and backgrounds
enum FolderTabDesign {
    // MARK: - Tab Dimensions

    /// Height of the tab content area
    static let tabHeight: CGFloat = 32

    /// Horizontal padding inside tabs
    static let horizontalPadding: CGFloat = 48

    /// Vertical padding inside tabs
    static let verticalPadding: CGFloat = 8

    /// The curve width factor for the selected tab shape (0.0 to 0.5)
    static let tabCurveWidthFactor: CGFloat = 0.35

    /// How much the selected tab extends below inactive tabs
    static let selectedTabExtension: CGFloat = 4

    /// Spacing between tabs
    static let tabSpacing: CGFloat = 4

    // MARK: - Background Colors

    /// Background color for the chrome area (nav bar, tab bar, unselected tabs)
    /// This creates visual continuity from top of screen through the tab bar
    static let chromeBackground = Color(.secondarySystemBackground)

    /// Background color for selected tab and content area (same color, no dots on tab)
    static let selectedBackground = Color(.systemBackground)

    /// Background color for inactive tabs - now transparent to show chrome through
    static let inactiveBackground = Color.clear

    // MARK: - Dot Grid Configuration

    /// Base spacing unit - derived from dot grid for visual harmony
    static let gridUnit: CGFloat = 25

    /// Default dot grid configuration for content areas
    static let dotGridConfig = DotGridConfiguration(
        dotColor: .blue.opacity(0.35),
        dotSize: 2,
        dotSpacing: gridUnit,
        backgroundColor: selectedBackground
    )

    // MARK: - Task Row Dimensions

    /// Vertical padding for task rows - minimal to keep rows compact
    static let taskRowVerticalPadding: CGFloat = 2

    /// Horizontal padding for task rows
    static let taskRowHorizontalPadding: CGFloat = 16

    /// Minimum row height - aligned with grid unit for visual rhythm
    static let taskRowMinHeight: CGFloat = gridUnit
}

// MARK: - SpreadTab

/// A single tab view representing a spread in the folder-style tab bar.
/// Selected tabs appear as the "front" folder with a custom curved shape.
/// Unselected tabs appear as recessed folder tabs behind the selected one.
struct SpreadTab: View {
    let spread: DataModel.Spread
    let isSelected: Bool
    var isCreatable: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            tabContent
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        if isSelected {
            selectedTabView
        } else {
            inactiveTabView
        }
    }

    private var selectedTabView: some View {
        Text(displayText)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .padding(.horizontal, FolderTabDesign.horizontalPadding)
            .padding(.vertical, FolderTabDesign.verticalPadding)
            .background(
                TabShape(curveWidthFactor: FolderTabDesign.tabCurveWidthFactor)
                    .fill(FolderTabDesign.selectedBackground)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -1)
            )
    }

    private var inactiveTabView: some View {
        Text(displayText)
            .font(.subheadline)
            .fontWeight(.regular)
            .foregroundStyle(isCreatable ? .tertiary : .secondary)
            .padding(.horizontal, FolderTabDesign.horizontalPadding - 4)
            .padding(.vertical, FolderTabDesign.verticalPadding - 2)
            // No background - text floats on chrome background for visual continuity
            .opacity(isCreatable ? 0.6 : 1.0)
    }

    /// Short date format based on period
    private var displayText: String {
        let calendar = Calendar.current
        switch spread.period {
        case .year:
            let year = calendar.component(.year, from: spread.date)
            return "\(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yy"
            return formatter.string(from: spread.date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: spread.date) + "+"
        case .week:
            let weekOfYear = calendar.component(.weekOfYear, from: spread.date)
            let year = calendar.component(.year, from: spread.date)
            return "W\(weekOfYear) \(year % 100)"
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: spread.date)
        }
    }
}

// MARK: - CreatableSpreadTab

/// A ghost tab for spreads that can be created.
/// Appears with a dashed border to indicate it's a creation action.
struct CreatableSpreadTab: View {
    let period: DataModel.Spread.Period
    let date: Date
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.caption2)
                Text(displayText)
                    .font(.subheadline)
            }
            .foregroundStyle(.tertiary)
            .padding(.horizontal, FolderTabDesign.horizontalPadding - 4)
            .padding(.vertical, FolderTabDesign.verticalPadding - 2)
            // Dashed underline to indicate tappable creation action
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                    .mask(
                        HStack(spacing: 4) {
                            ForEach(0..<10, id: \.self) { _ in
                                Rectangle()
                                    .frame(width: 4)
                            }
                        }
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var displayText: String {
        let calendar = Calendar.current
        switch period {
        case .year:
            let year = calendar.component(.year, from: date)
            return "\(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yy"
            return formatter.string(from: date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date) + "+"
        case .week:
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.year, from: date)
            return "W\(weekOfYear) \(year % 100)"
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Previews

#Preview("Folder Tabs") {
    let calendar = Calendar.current
    let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let monthDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
    let dayDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

    return VStack(spacing: 0) {
        // Tab bar area with chrome background (continuous to top)
        HStack(alignment: .bottom, spacing: FolderTabDesign.tabSpacing) {
            SpreadTab(
                spread: DataModel.Spread(period: .year, date: yearDate),
                isSelected: false,
                onTap: {}
            )
            SpreadTab(
                spread: DataModel.Spread(period: .month, date: monthDate),
                isSelected: true,
                onTap: {}
            )
            SpreadTab(
                spread: DataModel.Spread(period: .day, date: dayDate),
                isSelected: false,
                onTap: {}
            )
            CreatableSpreadTab(
                period: .day,
                date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!,
                onTap: {}
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FolderTabDesign.chromeBackground)

        // Content area with dot grid (same base color as selected tab)
        DotGridView(configuration: FolderTabDesign.dotGridConfig)
            .frame(height: 200)
    }
}

#Preview("Tab States") {
    let calendar = Calendar.current
    let monthDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

    return VStack(spacing: 24) {
        VStack(alignment: .leading) {
            Text("Selected").font(.caption).foregroundStyle(.secondary)
            SpreadTab(
                spread: DataModel.Spread(period: .month, date: monthDate),
                isSelected: true,
                onTap: {}
            )
        }

        VStack(alignment: .leading) {
            Text("Inactive (no background)").font(.caption).foregroundStyle(.secondary)
            SpreadTab(
                spread: DataModel.Spread(period: .month, date: monthDate),
                isSelected: false,
                onTap: {}
            )
        }

        VStack(alignment: .leading) {
            Text("Creatable (dashed underline)").font(.caption).foregroundStyle(.secondary)
            CreatableSpreadTab(
                period: .month,
                date: monthDate,
                onTap: {}
            )
        }
    }
    .padding()
    .background(FolderTabDesign.chromeBackground)
}
