//
//  JournalDataModelBuilder.swift
//  Spread
//
//  Created by Johnny O on 5/26/26.
//

import Foundation

/// Builds a `JournalDataModel` and per-spread data models from explicit spreads and entries.
///
/// Adopt this protocol to substitute a custom builder at the `JournalManager` DI boundary — for
/// example, a tracking wrapper in tests.
protocol JournalDataModelBuilder {
    /// Builds the complete journal data model from all explicit spreads and entries.
    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel

    /// Rebuilds one explicit spread surface for scoped `JournalManager` patching.
    ///
    /// Returns `nil` only when the matching explicit spread no longer exists.
    func buildSpreadDataModel(
        for key: SpreadDataModelKey,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel?

    /// Returns all spread data-model keys on which a task should appear.
    func spreadKeys(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey>

    /// Returns all spread data-model keys on which a note should appear.
    func spreadKeys(
        for note: DataModel.Note,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey>

    /// Returns the canonical derived-model key for an explicit spread.
    func spreadKey(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModelKey?
}
