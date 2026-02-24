import SwiftUI

struct LocationSearchBar: View {
    let placeholder: String
    @Binding var selectedLocation: LocationResult?
    var onSelect: ((LocationResult) -> Void)?

    @State private var searchText = ""
    @State private var results: [LocationResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let searchService = AppleLocationSearchService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(AppColors.primaryBlueDark)
                    .font(.appRegular(size: 20))

                if let location = selectedLocation {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .font(.appRegular(size: 16))
                            if !location.subtitle.isEmpty {
                                Text(location.subtitle)
                                    .font(.appRegular(size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        Spacer()
                        Button {
                            selectedLocation = nil
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                } else {
                    TextField(placeholder, text: $searchText)
                        .font(.appRegular(size: 16))
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            // Search results
            if !results.isEmpty && selectedLocation == nil {
                VStack(spacing: 0) {
                    ForEach(results) { result in
                        Button {
                            selectedLocation = result
                            onSelect?(result)
                            results = []
                            searchText = ""
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin")
                                    .foregroundStyle(AppColors.primaryBlueDark)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                        .font(.appRegular(size: 15))
                                        .foregroundStyle(AppColors.textPrimary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.appRegular(size: 12))
                                            .foregroundStyle(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        if result.id != results.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }

            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            guard !newValue.isEmpty else {
                results = []
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                isSearching = true
                do {
                    let searchResults = try await searchService.search(query: newValue)
                    if !Task.isCancelled {
                        results = searchResults
                    }
                } catch {}
                isSearching = false
            }
        }
    }
}
