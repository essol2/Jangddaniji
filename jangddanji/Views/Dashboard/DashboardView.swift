import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(filter: #Predicate<Journey> { $0.statusRawValue == "active" })
    private var activeJourneys: [Journey]
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let journey = activeJourneys.first {
            DashboardContentView(journey: journey)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "map")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("진행 중인 여정이 없습니다")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
                Button {
                    router.popToRoot()
                } label: {
                    Text("처음으로")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 160, height: 48)
                        .background(AppColors.primaryBlueDark)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .navigationBarHidden(true)
        }
    }
}

private struct DashboardContentView: View {
    let journey: Journey
    @State private var viewModel: DashboardViewModel
    @State private var showMapAppPicker = false
    @State private var selectedDayRoute: DayRoute?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(journey: Journey) {
        self.journey = journey
        _viewModel = State(initialValue: DashboardViewModel(journey: journey))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                VStack(spacing: 16) {
                    completionCard

                    if let today = viewModel.todayRoute {
                        todayCard(today)
                    }

                    scheduleSection
                }
                .padding(16)
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.updateStatuses(context: modelContext)
        }
        .onChange(of: journey.statusRawValue) { _, newValue in
            if newValue == JourneyStatus.completed.rawValue {
                router.popToRoot()
            }
        }
        .confirmationDialog(
            "길찾기 앱 선택",
            isPresented: $showMapAppPicker,
            titleVisibility: .visible
        ) {
            ForEach(viewModel.availableMapApps) { app in
                Button(app.rawValue) {
                    if let dayRoute = selectedDayRoute {
                        viewModel.openDirections(for: dayRoute, with: app)
                    }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("장딴지")
                    .font(.jejuDoldam(size: 26))
                    .foregroundStyle(AppColors.textPrimary)
                Text(journey.title)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                Text("\(AppDateFormatter.shortDate.string(from: journey.startDate)) ~ \(AppDateFormatter.shortDate.string(from: journey.endDate))")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.8))
            }

            Spacer()

            Button {
                router.navigateTo(.archiveList)
            } label: {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.primaryBlueDark)
                    .padding(10)
                    .background(.white.opacity(0.8))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.headerGradient)
    }

    // MARK: - Completion card

    private var completionCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(viewModel.completionPercentage)%")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(AppColors.accentYellow)
                Text("완주")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.bottom, 8)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("남은 거리")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(DistanceFormatter.formattedDetailed(viewModel.remainingDistance))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            ProgressBarView(progress: viewModel.completionRate)
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Today's card

    private func todayCard(_ dayRoute: DayRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘의 구간")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Day \(dayRoute.dayNumber) · \(AppDateFormatter.dayMonth.string(from: dayRoute.date))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.7))
                Text(dayRoute.startLocationName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Text(dayRoute.endLocationName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
            }

            HStack {
                Label(DistanceFormatter.formattedDetailed(dayRoute.distance), systemImage: "figure.walk")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        selectedDayRoute = dayRoute
                        showMapAppPicker = true
                    } label: {
                        Label("길찾기", systemImage: "map.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.primaryBlueDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        viewModel.markCompleted(context: modelContext)
                    } label: {
                        Label("완료", systemImage: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.primaryBlueDark)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.primaryBlueDark.opacity(0.35), radius: 8, y: 4)
        .onTapGesture {
            router.navigateTo(.dayDetail(dayRouteID: dayRoute.id))
        }
    }

    // MARK: - Schedule section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("전체 일정")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 8) {
                ForEach(journey.sortedDayRoutes) { dayRoute in
                    DayRouteRowView(dayRoute: dayRoute)
                        .onTapGesture {
                            router.navigateTo(.dayDetail(dayRouteID: dayRoute.id))
                        }
                        .contextMenu {
                            if dayRoute.status == .today || dayRoute.status == .completed {
                                Button {
                                    router.navigateTo(.routeModify(dayRouteID: dayRoute.id))
                                } label: {
                                    Label("경로 수정", systemImage: "pencil")
                                }
                            }
                        }
                }
            }
        }
    }
}
