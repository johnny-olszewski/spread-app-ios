//
//  StatusIcon.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// A view that displays a task status icon.
/// - Open: bullet point (•)
/// - Complete: X mark
/// - Migrated: arrow (→)
struct StatusIcon: View {
    let status: DataModel.Task.Status
    var size: CGFloat = 16
    var color: Color?

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch status {
        case .open:
            return "circle"
        case .complete:
            return "xmark"
        case .migrated:
            return "arrow.right"
        }
    }

    private var iconColor: Color {
        if let color = color {
            return color
        }
        switch status {
        case .open:
            return .primary
        case .complete:
            return .primary
        case .migrated:
            return .secondary
        }
    }
}

#Preview("All Status Icons") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            StatusIcon(status: .open)
            Text("Open")
        }
        HStack(spacing: 20) {
            StatusIcon(status: .complete)
            Text("Complete")
        }
        HStack(spacing: 20) {
            StatusIcon(status: .migrated)
            Text("Migrated")
        }
    }
    .padding()
}

#Preview("Sizes") {
    HStack(spacing: 20) {
        StatusIcon(status: .open, size: 12)
        StatusIcon(status: .open, size: 16)
        StatusIcon(status: .open, size: 24)
    }
    .padding()
}
