import Foundation

/// Content mode for the Entries tab.
enum EntriesBrowserContentMode {
    case tasks
    case notes
}

/// Navigation destinations within the filter/management navigation stack.
enum ManagementDestination: Hashable {
    case lists
    case tags
}

/// Manages filter state, management navigation, and loaded list/tag data for the Entries tab.
@Observable @MainActor final class EntriesBrowserViewModel {

    // MARK: - Content Mode

    var contentMode: EntriesBrowserContentMode = .tasks

    // MARK: - Filter State

    var selectedList: DataModel.List?
    var selectedTagIDs: Set<UUID> = []
    var isFilterSheetPresented = false
    var searchText = ""

    // MARK: - Management Navigation

    /// Path shared by both the compact filter sheet and the regular management sheet.
    ///
    /// Pre-populate before setting `isManagementSheetPresented = true` to deep-link
    /// directly to the list or tag management view from the persistent filter card.
    var managementNavPath: [ManagementDestination] = []

    /// Controls the management sheet presented from the regular (persistent card) layout.
    var isManagementSheetPresented = false

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

    /// Reloads lists and tags, then removes any stale filter selections that no longer exist.
    func refreshListsAndTags(listRepository: any ListRepository, tagRepository: any TagRepository) async {
        await loadListsAndTags(listRepository: listRepository, tagRepository: tagRepository)
        if let selected = selectedList, !lists.contains(where: { $0.id == selected.id }) {
            selectedList = nil
        }
        selectedTagIDs = selectedTagIDs.filter { id in tags.contains { $0.id == id } }
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
