import Foundation

protocol OverdueEvaluator {
    func overdueTaskItems(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread]
    ) -> [OverdueTaskItem]
}

struct StandardOverdueEvaluator: OverdueEvaluator {
    let calendar: Calendar
    let today: Date
    let migrationPlanner: any MigrationPlanner

    func overdueTaskItems(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread]
    ) -> [OverdueTaskItem] {
        tasks.compactMap { task in
            overdueTaskItem(for: task, spreads: spreads)
        }
    }

    private func overdueTaskItem(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> OverdueTaskItem? {
        guard task.status == .open else {
            return nil
        }

        if let openSpread = migrationPlanner.currentDestinationSpread(
            for: task,
            spreads: spreads,
            excluding: nil
        ) {
            let sourceKey = TaskReviewSourceKey(
                kind: .spread(
                    id: openSpread.id,
                    period: openSpread.period,
                    date: openSpread.period.normalizeDate(openSpread.date, calendar: calendar)
                )
            )
            guard isOverdue(date: openSpread.date, period: openSpread.period) else {
                return nil
            }
            return OverdueTaskItem(task: task, sourceKey: sourceKey)
        }

        guard isOverdue(date: task.date, period: task.period) else {
            return nil
        }
        return OverdueTaskItem(task: task, sourceKey: .init(kind: .inbox))
    }

    private func isOverdue(date: Date, period: Period) -> Bool {
        let todayStart = today.startOfDay(calendar: calendar)

        switch period {
        case .day:
            let dueDay = date.startOfDay(calendar: calendar)
            return todayStart > dueDay
        case .month:
            let startOfMonth = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return false
            }
            return todayStart >= startOfNextMonth
        case .year:
            let startOfYear = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return false
            }
            return todayStart >= startOfNextYear
        case .multiday:
            return false
        }
    }
}
