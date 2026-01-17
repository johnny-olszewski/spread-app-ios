#if DEBUG
import SwiftUI

/// Enum representing the different repository types that can be inspected.
enum DebugRepositoryType: String, CaseIterable, Identifiable {
    case tasks
    case spreads
    case events
    case notes
    case collections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "Tasks"
        case .spreads: return "Spreads"
        case .events: return "Events"
        case .notes: return "Notes"
        case .collections: return "Collections"
        }
    }

    var systemImage: String {
        switch self {
        case .tasks: return "checkmark.circle"
        case .spreads: return "book"
        case .events: return "calendar"
        case .notes: return "note.text"
        case .collections: return "folder"
        }
    }
}

/// Debug view for browsing repository contents.
///
/// Displays all items in a selected repository with key properties.
/// Only available in DEBUG builds.
struct DebugRepositoryListView: View {
    let repositoryType: DebugRepositoryType
    let container: DependencyContainer

    @State private var tasks: [DataModel.Task] = []
    @State private var spreads: [DataModel.Spread] = []
    @State private var events: [DataModel.Event] = []
    @State private var notes: [DataModel.Note] = []
    @State private var collections: [DataModel.Collection] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else {
                listContent
            }
        }
        .navigationTitle(repositoryType.title)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        switch repositoryType {
        case .tasks:
            tasksList
        case .spreads:
            spreadsList
        case .events:
            eventsList
        case .notes:
            notesList
        case .collections:
            collectionsList
        }
    }

    // MARK: - Tasks List

    private var tasksList: some View {
        List {
            if tasks.isEmpty {
                emptyState
            } else {
                ForEach(tasks, id: \.id) { task in
                    taskRow(task)
                }
            }
        }
    }

    private func taskRow(_ task: DataModel.Task) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Label(task.status.rawValue, systemImage: statusIcon(for: task.status))
                Label("\(task.assignments.count) assignments", systemImage: "link")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Created: \(task.createdDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("ID: \(task.id.uuidString.prefix(8))...")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.vertical, 2)
    }

    private func statusIcon(for status: DataModel.Task.Status) -> String {
        switch status {
        case .open: return "circle"
        case .complete: return "checkmark.circle.fill"
        case .migrated: return "arrow.right.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    // MARK: - Spreads List

    private var spreadsList: some View {
        List {
            if spreads.isEmpty {
                emptyState
            } else {
                ForEach(spreads, id: \.id) { spread in
                    spreadRow(spread)
                }
            }
        }
    }

    private func spreadRow(_ spread: DataModel.Spread) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(spread.period.displayName, systemImage: periodIcon(for: spread.period))
                    .fontWeight(.medium)

                Spacer()

                Text(spreadDateDisplay(spread))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if spread.period == .multiday, let start = spread.startDate, let end = spread.endDate {
                Text("\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Created: \(spread.createdDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("ID: \(spread.id.uuidString.prefix(8))...")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.vertical, 2)
    }

    private func periodIcon(for period: Period) -> String {
        switch period {
        case .year: return "calendar"
        case .month: return "calendar.badge.clock"
        case .day: return "sun.max"
        case .multiday: return "calendar.day.timeline.left"
        }
    }

    private func spreadDateDisplay(_ spread: DataModel.Spread) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current

        switch spread.period {
        case .year:
            formatter.dateFormat = "yyyy"
        case .month:
            formatter.dateFormat = "MMM yyyy"
        case .day:
            formatter.dateFormat = "MMM d, yyyy"
        case .multiday:
            return "Multiday"
        }

        return formatter.string(from: spread.date)
    }

    // MARK: - Events List

    private var eventsList: some View {
        List {
            if events.isEmpty {
                emptyState
            } else {
                ForEach(events, id: \.id) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: DataModel.Event) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Label(event.timing.displayName, systemImage: timingIcon(for: event.timing))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("\(event.startDate.formatted(date: .abbreviated, time: .omitted)) - \(event.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let startTime = event.startTime, let endTime = event.endTime {
                Text("\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Created: \(event.createdDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("ID: \(event.id.uuidString.prefix(8))...")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.vertical, 2)
    }

    private func timingIcon(for timing: EventTiming) -> String {
        switch timing {
        case .singleDay: return "calendar"
        case .allDay: return "sun.max.fill"
        case .timed: return "clock"
        case .multiDay: return "calendar.day.timeline.left"
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        List {
            if notes.isEmpty {
                emptyState
            } else {
                ForEach(notes, id: \.id) { note in
                    noteRow(note)
                }
            }
        }
    }

    private func noteRow(_ note: DataModel.Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .fontWeight(.medium)

            if !note.content.isEmpty {
                Text(note.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label(note.status.rawValue, systemImage: noteStatusIcon(for: note.status))
                Label("\(note.assignments.count) assignments", systemImage: "link")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Created: \(note.createdDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("ID: \(note.id.uuidString.prefix(8))...")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.vertical, 2)
    }

    private func noteStatusIcon(for status: DataModel.Note.Status) -> String {
        switch status {
        case .active: return "circle.fill"
        case .migrated: return "arrow.right.circle"
        }
    }

    // MARK: - Collections List

    private var collectionsList: some View {
        List {
            if collections.isEmpty {
                emptyState
            } else {
                ForEach(collections, id: \.id) { collection in
                    collectionRow(collection)
                }
            }
        }
    }

    private func collectionRow(_ collection: DataModel.Collection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collection.title)
                .fontWeight(.medium)

            Text("Created: \(collection.createdDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("ID: \(collection.id.uuidString.prefix(8))...")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No \(repositoryType.title)", systemImage: repositoryType.systemImage)
        } description: {
            Text("This repository is empty.")
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        switch repositoryType {
        case .tasks:
            tasks = await container.taskRepository.getTasks()
        case .spreads:
            spreads = await container.spreadRepository.getSpreads()
        case .events:
            events = await container.eventRepository.getEvents()
        case .notes:
            notes = await container.noteRepository.getNotes()
        case .collections:
            collections = await container.collectionRepository.getCollections()
        }

        isLoading = false
    }
}

#Preview("Tasks") {
    NavigationStack {
        DebugRepositoryListView(
            repositoryType: .tasks,
            container: try! .makeForPreview()
        )
    }
}

#Preview("Spreads") {
    NavigationStack {
        DebugRepositoryListView(
            repositoryType: .spreads,
            container: try! .makeForPreview()
        )
    }
}
#endif
