//
//  ModeToggleView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Compact toggle for switching between Conventional and Traditional modes.
/// Can be used inline in the main view toolbar.
struct ModeToggleView: View {
    @Environment(JournalManager.self) private var journalManager

    var body: some View {
        @Bindable var manager = journalManager

        Menu {
            ForEach(DataModel.BujoMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation {
                        manager.bujoMode = mode
                    }
                } label: {
                    HStack {
                        Text(mode.displayName)
                        if manager.bujoMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: modeIcon)
                Text(journalManager.bujoMode.shortName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(.systemGray5))
            )
        }
    }

    private var modeIcon: String {
        switch journalManager.bujoMode {
        case .convential:
            return "arrow.right.arrow.left"
        case .traditional:
            return "list.bullet"
        }
    }
}

// MARK: - BujoMode Extensions

extension DataModel.BujoMode {
    var displayName: String {
        switch self {
        case .convential:
            return "Conventional"
        case .traditional:
            return "Traditional"
        }
    }

    var shortName: String {
        switch self {
        case .convential:
            return "Conv"
        case .traditional:
            return "Trad"
        }
    }

    var description: String {
        switch self {
        case .convential:
            return "Shows task migration history across spreads. Tasks appear on the spread they were migrated to and show as migrated on previous spreads."
        case .traditional:
            return "Tasks appear only on their preferred assignment. No migration history is shown."
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()

    return HStack {
        ModeToggleView()
        Spacer()
    }
    .padding()
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
