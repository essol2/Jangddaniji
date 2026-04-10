import Foundation

@Observable
final class HikingSetupViewModel {

    var searchQuery: String = ""
    var searchResults: [LocationResult] = []
    var selectedMountain: LocationResult?
    var isSearching = false
    var errorMessage: String?

    private let locationService: LocationSearchServiceProtocol

    init(locationService: LocationSearchServiceProtocol = NaverLocationSearchService()) {
        self.locationService = locationService
    }

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            searchResults = try await locationService.search(query: query)
        } catch {
            errorMessage = "검색 중 오류가 발생했습니다."
            searchResults = []
        }

        isSearching = false
    }

    func select(_ mountain: LocationResult) {
        selectedMountain = mountain
        searchResults = []
        searchQuery = mountain.name
    }

    func clearSelection() {
        selectedMountain = nil
        searchQuery = ""
        searchResults = []
    }
}
