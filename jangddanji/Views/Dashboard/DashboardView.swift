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
                    .font(.appRegular(size: 48))
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("진행 중인 여정이 없습니다")
                    .font(.appRegular(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
                Button {
                    router.popToRoot()
                } label: {
                    Text("처음으로")
                        .font(.appBold(size: 16))
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

                VStack(spacing: 20) {
                    completionCard

                    if let today = viewModel.todayRoute {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("오늘의 구간")
                                .font(.appBold(size: 16))
                                .foregroundStyle(AppColors.textPrimary)
                            todayCard(today)
                        }
                    }

                    scheduleSection
                }
                .padding(20)
            }
        }
        .background(Color.white)
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
        VStack(alignment: .leading, spacing: 10) {
            Button {
                router.pop()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.appRegular(size: 13))
                    Text("돌아가기")
                        .font(.appRegular(size: 14))
                }
                .foregroundStyle(AppColors.primaryBlueDark)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(journey.title)
                    .font(.appBold(size: 26))
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(AppDateFormatter.shortDate.string(from: journey.startDate)) ~ \(AppDateFormatter.shortDate.string(from: journey.endDate))")
                    .font(.appRegular(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
    }

    // MARK: - Completion card

    private var completionCard: some View {
        VStack(spacing: 14) {
            Text("\(viewModel.completionPercentage)% 완주")
                .font(.appBold(size: 36))
                .foregroundStyle(AppColors.primaryBlueDark)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("목표의 \(viewModel.completedCount)/\(viewModel.totalCount) 지점을 통과했어요")
                .font(.appRegular(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 6) {
                ProgressBarView(progress: viewModel.completionRate)

                HStack {
                    Text("시작")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("완료")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Today card

    private func todayCard(_ dayRoute: DayRoute) -> some View {
        VStack(spacing: 16) {
            // Two-column: departure | icon | arrival
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.appRegular(size: 22))
                        .foregroundStyle(AppColors.primaryBlueDark)
                    Text(dayRoute.startLocationName)
                        .font(.appBold(size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text("출발지")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "figure.walk")
                    .font(.appRegular(size: 26))
                    .foregroundStyle(AppColors.primaryBlueDark)
                    .frame(width: 50)

                VStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.appRegular(size: 22))
                        .foregroundStyle(AppColors.primaryBlueDark)
                    Text(dayRoute.endLocationName)
                        .font(.appBold(size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text("도착지")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Bottom: 남은 거리 + buttons
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("남은 거리")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(DistanceFormatter.formattedDetailed(dayRoute.distance))
                        .font(.appBold(size: 18))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        selectedDayRoute = dayRoute
                        showMapAppPicker = true
                    } label: {
                        Label("길찾기", systemImage: "map.fill")
                            .font(.appBold(size: 13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.primaryBlueDark)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        viewModel.markCompleted(context: modelContext)
                    } label: {
                        Label("완료", systemImage: "checkmark")
                            .font(.appBold(size: 13))
                            .foregroundStyle(AppColors.primaryBlueDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.primaryBlueDark.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .onTapGesture {
            router.navigateTo(.dayDetail(dayRouteID: dayRoute.id))
        }
    }

    // MARK: - Schedule section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("전체 일정")
                .font(.appBold(size: 16))
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
