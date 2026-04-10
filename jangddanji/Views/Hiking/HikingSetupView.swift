import SwiftUI

struct HikingSetupView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = HikingSetupViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                searchCard
                if !viewModel.searchResults.isEmpty {
                    searchResultsCard
                }
                if viewModel.selectedMountain != nil {
                    startCard
                }
            }
            .padding(20)
        }
        .background(AppColors.background)
        .navigationTitle("등산 기록")
        .navigationBarTitleDisplayMode(.large)
        .alert("검색 오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Search Card

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "mountain.2.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("어떤 산을 오르시나요?")
                    .font(.appBold(size: 18))
                    .foregroundStyle(AppColors.textPrimary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.textSecondary)

                TextField("산 이름 검색 (예: 북한산)", text: $viewModel.searchQuery)
                    .font(.appRegular(size: 16))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }
                    .onChange(of: viewModel.searchQuery) {
                        if viewModel.searchQuery.isEmpty {
                            viewModel.clearSelection()
                        }
                    }

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearSelection()
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if viewModel.selectedMountain == nil && !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                Button {
                    Task { await viewModel.search() }
                } label: {
                    Text("검색")
                        .font(.appBold(size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.primaryBlueDark)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Search Results

    private var searchResultsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("검색 결과")
                .font(.appBold(size: 14))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(viewModel.searchResults) { result in
                Button {
                    viewModel.select(result)
                    isSearchFocused = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppColors.primaryBlue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.appBold(size: 15))
                                .foregroundStyle(AppColors.textPrimary)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.appRegular(size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if result.id != viewModel.searchResults.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
            .padding(.bottom, 4)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Start Card

    private var startCard: some View {
        VStack(spacing: 16) {
            if let mountain = viewModel.selectedMountain {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.primaryBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mountain.name)
                            .font(.appBold(size: 17))
                            .foregroundStyle(AppColors.textPrimary)
                        if !mountain.subtitle.isEmpty {
                            Text(mountain.subtitle)
                                .font(.appRegular(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    Spacer()
                }
            }

            Button {
                guard let mountain = viewModel.selectedMountain else { return }
                router.navigateTo(.hikingTracking(
                    mountainName: mountain.name,
                    latitude: mountain.latitude,
                    longitude: mountain.longitude
                ))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.hiking")
                        .font(.appRegular(size: 18))
                    Text("등산 시작")
                        .font(.appBold(size: 17))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppColors.primaryBlueDark)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}
