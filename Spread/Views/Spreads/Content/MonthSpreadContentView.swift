import SwiftUI

private enum MonthSpreadContentLayout {
    static let sectionSpacing: CGFloat = 20
    static let contentPadding: CGFloat = 16
    static let sectionRowSpacing: CGFloat = 8
}

/// Renders a month spread as a calendar, month-level section, and day-section list.
struct MonthSpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let syncEngine: SyncEngine?

    @Environment(JournalManager.self) private var journalManager
    @Environment(SpreadsCoordinator.self) private var coordinator
    @State private var vm = ViewModel()

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var autoMigrationFeedback: SpreadAutoMigrationFeedback? {
        guard let feedback = coordinator.autoMigrationFeedback,
              feedback.surfaceSpreadID == spread.id else {
            return nil
        }
        return feedback
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let contentModel = vm.contentModel {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: MonthSpreadContentLayout.sectionSpacing) {
                            if autoMigrationFeedback?.anchor == .spreadHeader,
                               let message = autoMigrationFeedback?.message {
                                SpreadAutoMigrationCueView(message: message)
                            }

                            SpreadMonthCalendarView(
                                monthDate: spread.date,
                                mode: journalManager.bujoMode == .conventional ? .conventional : .traditional,
                                journalManager: journalManager,
                                calendarActionsByDate: contentModel.calendarActionsByDate,
                                onViewDaySpread: { explicitDaySpread in
                                    coordinator.selectSpread(explicitDaySpread)
                                },
                                onRevealMonthDaySection: { date in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(date, anchor: .top)
                                    }
                                }
                            )

                            monthSection(entries: contentModel.monthEntries)

                            ForEach(contentModel.daySections) { section in
                                daySection(section)
                                    .id(section.id)
                            }
                        }
                        .padding(.horizontal, MonthSpreadContentLayout.contentPadding)
                        .padding(.bottom, MonthSpreadContentLayout.sectionSpacing)
                    }
                }
            }
        }
        .task(id: spread.id) {
            vm.configure(
                spread: spread,
                spreadDataModel: spreadDataModel,
                journalManager: journalManager,
                syncEngine: syncEngine,
                coordinator: coordinator
            )
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            vm.refreshContentModel(
                spread: spread,
                spreadDataModel: spreadDataModel,
                journalManager: journalManager
            )
        }
    }

    @ViewBuilder
    private func monthSection(entries: [any Entry]) -> some View {
        VStack(alignment: .leading, spacing: MonthSpreadContentLayout.sectionRowSpacing) {
            Text("Month")
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            if entries.isEmpty {
                Text("No month-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.medium)
            } else {
                EntryListView(
                    sections: [EntryList.Section(
                        id: "month-entries",
                        title: "",
                        date: spread.date,
                        entries: entries,
                        creationPeriod: .month,
                        creationDate: spread.date
                    )],
                    configurationMap: vm.configurationMap,
                    style: .inline
                )
            }
        }
    }

    @ViewBuilder
    private func daySection(_ section: MonthSpreadDaySectionModel) -> some View {
        let isAutoMigrationDestination = autoMigrationFeedback.map {
            if case .monthDay(let date) = $0.anchor {
                return date == section.date
            }
            return false
        } ?? false

        VStack(alignment: .leading, spacing: MonthSpreadContentLayout.sectionRowSpacing) {
            daySectionHeader(section)

            if isAutoMigrationDestination, let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
            }

            if section.entries.isEmpty {
                Text("No day-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.small)
            } else {
                EntryListView(
                    sections: [EntryList.Section(
                        id: section.date.timeIntervalSinceReferenceDate.description,
                        title: "",
                        date: section.date,
                        entries: section.entries,
                        creationPeriod: .day,
                        creationDate: section.date
                    )],
                    configurationMap: vm.configurationMap,
                    style: .inline
                )
            }
        }
        .padding(.horizontal, isAutoMigrationDestination ? 12 : 0)
        .padding(.vertical, isAutoMigrationDestination ? 10 : 0)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isAutoMigrationDestination
                        ? SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.08)
                        : Color.clear
                )
        )
    }

    @ViewBuilder
    private func daySectionHeader(_ section: MonthSpreadDaySectionModel) -> some View {
        Text(daySectionTitle(for: section.date))
            .font(SpreadTheme.Typography.title3)
            .foregroundStyle(.primary)
    }

    private func daySectionTitle(for date: Date) -> String {
        date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
        )
    }
}
