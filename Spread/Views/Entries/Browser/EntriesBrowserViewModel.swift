import Foundation

/// Content mode for the Entries tab.
enum EntriesBrowserContentMode {
    case tasks
    case notes
}

/// Manages filter state and loaded list/tag data for the Entries tab.
@Observable @MainActor final class EntriesBrowserViewModel {

    // MARK: - Content Mode

    var contentMode: EntriesBrowserContentMode = .tasks

    // MARK: - Filter State

    var selectedList: DataModel.List?
    var selectedTagIDs: Set<UUID> = []
    var isFilterSheetPresented = false
    var searchText = ""

    // MARK: - Loaded Data

    private(set) var lists: [DataModel.List] = []
    private(set) var tags: [DataModel.Tag] = []

    // MARK: - Derived

    var hasActiveFilters: Bool {
        selectedList != nil || !selectedTagIDs.isEmpty
    }

    // MARK: - Actions

    func loadListsAndTags(listRepository: any ListRepository, tagRepository: any TagRepository) async {
        async let fetchedLists = listRepository.getLists()
        async let fetchedTags = tagRepository.getTags()
        lists = await fetchedLists
        tags = await fetchedTags
    }

    func clearFilters() {
        selectedList = nil
        selectedTagIDs = []
    }

    func toggleTag(_ tag: DataModel.Tag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
    }
}
