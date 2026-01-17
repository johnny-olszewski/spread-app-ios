//
//  TaskRowView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// A single task display row with status icon, title, and swipe actions.
struct TaskRowView: View {
    let task: DataModel.Task
    let status: DataModel.Task.Status
    let canMigrate: Bool
    let onTap: () -> Void
    let onComplete: () -> Void
    let onMigrate: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                StatusIcon(status: status)
                    .frame(width: 16)

                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
                    .strikethrough(status == .complete)

                Spacer()

                if status == .migrated {
                    Text("migrated")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, FolderTabDesign.taskRowVerticalPadding)
            .frame(minHeight: FolderTabDesign.taskRowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if status == .open {
                Button {
                    onComplete()
                } label: {
                    Label("Complete", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if canMigrate && status == .open {
                Button {
                    onMigrate()
                } label: {
                    Label("Migrate", systemImage: "arrow.right")
                }
                .tint(.blue)
            }
        }
    }

    private var textColor: Color {
        switch status {
        case .open:
            return .primary
        case .complete:
            return .secondary
        case .migrated:
            return .secondary
        }
    }
}

/// A simplified version of TaskRowView for the migrated tasks section
struct MigratedTaskRowView: View {
    let task: DataModel.Task
    let destinationDescription: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                StatusIcon(status: .migrated, color: .secondary)
                    .frame(width: 16)

                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let destination = destinationDescription {
                    Text("→ \(destination)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, FolderTabDesign.taskRowVerticalPadding)
            .padding(.horizontal, FolderTabDesign.taskRowHorizontalPadding)
            .frame(minHeight: FolderTabDesign.taskRowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    List {
        Section("Open Tasks") {
            TaskRowView(
                task: DataModel.Task(title: "Buy groceries", date: Date(), period: .day, status: .open),
                status: .open,
                canMigrate: true,
                onTap: {},
                onComplete: {},
                onMigrate: {}
            )
            TaskRowView(
                task: DataModel.Task(title: "Call dentist", date: Date(), period: .day, status: .open),
                status: .open,
                canMigrate: false,
                onTap: {},
                onComplete: {},
                onMigrate: {}
            )
        }

        Section("Completed Tasks") {
            TaskRowView(
                task: DataModel.Task(title: "Send email", date: Date(), period: .day, status: .complete),
                status: .complete,
                canMigrate: false,
                onTap: {},
                onComplete: {},
                onMigrate: {}
            )
        }

        Section("Migrated Tasks") {
            MigratedTaskRowView(
                task: DataModel.Task(title: "Review proposal", date: Date(), period: .day, status: .migrated),
                destinationDescription: "Feb 26",
                onTap: {}
            )
        }
    }
}
