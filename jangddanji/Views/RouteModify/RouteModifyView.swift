import SwiftUI
import SwiftData

struct RouteModifyView: View {
    let dayRouteID: UUID
    @Query private var dayRoutes: [DayRoute]

    init(dayRouteID: UUID) {
        self.dayRouteID = dayRouteID
        _dayRoutes = Query(filter: #Predicate<DayRoute> { $0.id == dayRouteID })
    }

    var body: some View {
        if let dayRoute = dayRoutes.first, dayRoute.journey != nil {
            RouteModifyContentView(dayRoute: dayRoute)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
        }
    }
}

private struct RouteModifyContentView: View {
    let dayRoute: DayRoute
    @State private var viewModel: RouteModifyViewModel
    @State private var searchQuery = ""
    @State private var remainingDaysCount = 1
    @State private var showConfirmAlert = false
    @State private var searchDebounceTask: Task<Void, Never>?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(dayRoute: DayRoute) {
        self.dayRoute = dayRoute
        _viewModel = State(initialValue: RouteModifyViewModel(dayRoute: dayRoute))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                VStack(spacing: 16) {
                    currentRouteCard
                    newEndLocationCard
                    remainingDaysCard

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.appRegular(size: 13))
                            .foregroundStyle(.red)
                            .padding(12)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    confirmButton
                }
                .padding(16)
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
        .onAppear {
            searchQuery = dayRoute.endLocationName
            remainingDaysCount = viewModel.initialRemainingDays
        }
        .alert("경로 재계산", isPresented: $showConfirmAlert) {
            Button("취소", role: .cancel) {}
            Button("수정하기") {
                Task {
                    await viewModel.recalculate(remainingDaysCount: remainingDaysCount, context: modelContext)
                    if viewModel.errorMessage == nil {
                        router.pop()
                    }
                }
            }
        } message: {
            Text("이후 루트 데이터가 모두 재계산됩니다.\n수정하시겠습니까?")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                router.pop()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.appBold(size: 14))
                    Text("뒤로")
                        .font(.appRegular(size: 15))
                }
                .foregroundStyle(AppColors.primaryBlueDark)
            }
            .padding(.bottom, 4)

            Text("경로 수정")
                .font(.appBold(size: 26))
                .foregroundStyle(AppColors.textPrimary)

            Text("Day \(dayRoute.dayNumber) · \(AppDateFormatter.dayMonth.string(from: dayRoute.date))")
                .font(.appRegular(size: 13))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.headerGradient)
    }

    // MARK: - Current route card

    private var currentRouteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("현재 구간")
                .font(.appBold(size: 14))
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.primaryBlueDark)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 2, height: 24)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(dayRoute.startLocationName)
                        .font(.appRegular(size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(dayRoute.endLocationName)
                        .font(.appRegular(size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                Text(DistanceFormatter.formattedDetailed(dayRoute.distance))
                    .font(.appBold(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - New end location

    private var newEndLocationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 도착지 변경")
                .font(.appBold(size: 14))
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.textSecondary)
                TextField("도착지 검색", text: $searchQuery)
                    .font(.appRegular(size: 15))
                    .onChange(of: searchQuery) { _, newQuery in
                        searchDebounceTask?.cancel()
                        searchDebounceTask = Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            guard !Task.isCancelled else { return }
                            await viewModel.searchLocations(query: newQuery)
                        }
                    }
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { result in
                        Button {
                            viewModel.selectLocation(result)
                            searchQuery = result.name
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.appRegular(size: 14))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(result.subtitle)
                                    .font(.appRegular(size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if result.id != viewModel.searchResults.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if viewModel.newEndLocationName != dayRoute.endLocationName {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.completedGreen)
                    Text("새 도착지: \(viewModel.newEndLocationName)")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.completedGreen)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Remaining days

    private var remainingDaysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("남은 일정 조정")
                .font(.appBold(size: 14))
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                Text("남은 날수")
                    .font(.appRegular(size: 15))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Stepper("\(remainingDaysCount)일", value: $remainingDaysCount, in: 1...60)
                    .fixedSize()
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Confirm button

    private var confirmButton: some View {
        Button {
            showConfirmAlert = true
        } label: {
            Group {
                if viewModel.isCalculating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("경로 재계산 중...")
                    }
                } else {
                    Text("경로 재계산하기")
                }
            }
            .font(.appBold(size: 17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(viewModel.isCalculating ? AppColors.primaryBlueDark.opacity(0.6) : AppColors.primaryBlueDark)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(viewModel.isCalculating)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
}
