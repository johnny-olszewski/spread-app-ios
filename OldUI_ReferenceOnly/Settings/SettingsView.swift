//
//  SettingsView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Full settings screen with mode selection and detailed explanations.
struct SettingsView: View {
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.dismiss) private var dismiss

    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    var body: some View {
        @Bindable var manager = journalManager

        NavigationStack {
            Form {
                // Mode Selection
                Section {
                    ForEach(DataModel.BujoMode.allCases, id: \.self) { mode in
                        ModeSelectionRow(
                            mode: mode,
                            isSelected: manager.bujoMode == mode,
                            onSelect: {
                                withAnimation {
                                    manager.bujoMode = mode
                                }
                            }
                        )
                    }
                } header: {
                    Text("Task Management Style")
                } footer: {
                    Text("Choose how tasks are displayed and managed across spreads.")
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://bulletjournal.com")!) {
                        HStack {
                            Text("Learn about Bullet Journaling")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                #if DEBUG
                // Debug section (only visible in debug builds)
                Section("Developer") {
                    Button {
                        showingDebugMenu = true
                    } label: {
                        HStack {
                            Image(systemName: "ant.fill")
                                .foregroundStyle(.orange)
                            Text("Debug Menu")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView()
            }
            #endif
        }
    }
}

/// A row for mode selection with description
private struct ModeSelectionRow: View {
    let mode: DataModel.BujoMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()

    return SettingsView()
        .environment(JournalManager(
            calendar: calendar,
            today: today,
            bujoMode: .convential,
            spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
            taskRepository: mock_TaskRepository(calendar: calendar, today: today)
        ))
}
