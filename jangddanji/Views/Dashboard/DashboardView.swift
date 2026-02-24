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
    @State private var pedometer = PedometerService()
    @State private var showMapAppPicker = false
    @State private var selectedDayRoute: DayRoute?
    @State private var showStopAlert = false
    @State private var showCelebration = false
    @StateObject private var adManager = NativeAdManager()
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(journey: Journey) {
        self.journey = journey
        _viewModel = State(initialValue: DashboardViewModel(journey: journey))
    }

    var body: some View {
        ZStack {
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

                    stopButton
                }
                .padding(20)
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.updateStatuses(context: modelContext)
            pedometer.setPeriodStart(journey.startDate)
            pedometer.requestAuthorization()
            adManager.loadAd()
        }
        .onChange(of: journey.statusRawValue) { _, newValue in
            if newValue == JourneyStatus.completed.rawValue {
                // 여정 완료 시 누적 걸음수/거리 저장
                journey.totalSteps = pedometer.totalSteps
                journey.totalDistanceWalked = pedometer.totalDistanceKm
                try? modelContext.save()
                router.popToRoot()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    router.navigateTo(.journeyComplete(journeyID: journey.id))
                }
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
        .alert("발걸음을 멈추시겠습니까?", isPresented: $showStopAlert) {
            Button("계속 걷기", role: .cancel) {}
            Button("중단하기", role: .destructive) {
                stopJourney()
            }
        } message: {
            Text("아직 모든 경로가 완료되지 않았습니다.\n중단하면 이 여정의 데이터가 삭제되며 복구할 수 없습니다.")
        }

            if showCelebration {
                CelebrationOverlayView(
                    steps: pedometer.todaySteps,
                    distanceKm: pedometer.todayDistanceKm,
                    isPresented: $showCelebration
                )
                .transition(.opacity)
            }
        } // ZStack
    }

    // MARK: - Stop button

    private var stopButton: some View {
        Button {
            showStopAlert = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "stop.circle")
                    .font(.appRegular(size: 15))
                Text("발걸음 멈추기")
                    .font(.appRegular(size: 14))
            }
            .foregroundStyle(.red.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.red.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 12)
    }

    private func stopJourney() {
        // Mark as abandoned first so EntryView's @Query won't find an active journey
        journey.status = .abandoned
        try? modelContext.save()
        // Navigate away
        router.popToRoot()
        // Delete after navigation completes to avoid accessing freed backing data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            modelContext.delete(journey)
            try? modelContext.save()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
    }

    // MARK: - Completion card

    private var completionCard: some View {
        HStack(spacing: 0) {
            // 완주율
            VStack(spacing: 4) {
                Text("\(viewModel.completionPercentage)%")
                    .font(.appBold(size: 17))
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("완주")
                    .font(.appRegular(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.15))
                .frame(width: 1, height: 28)

            // 구간 통과
            VStack(spacing: 4) {
                Text("\(viewModel.completedCount)/\(viewModel.totalCount)")
                    .font(.appBold(size: 17))
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("구간")
                    .font(.appRegular(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.15))
                .frame(width: 1, height: 28)

            // 총 걸음수
            VStack(spacing: 4) {
                Text(pedometer.totalSteps.formatted())
                    .font(.appBold(size: 17))
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("걸음")
                    .font(.appRegular(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.15))
                .frame(width: 1, height: 28)

            // 총 이동거리
            VStack(spacing: 4) {
                Text(String(format: "%.1f km", pedometer.totalDistanceKm))
                    .font(.appBold(size: 17))
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("이동")
                    .font(.appRegular(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }

    // MARK: - Today card

    private func todayCard(_ dayRoute: DayRoute) -> some View {
        VStack(spacing: 16) {
            // Two-column: departure | dotted line | icon | dotted line | arrival
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

                dottedLine

                Image(systemName: "figure.walk")
                    .font(.appRegular(size: 26))
                    .foregroundStyle(AppColors.primaryBlueDark)
                    .frame(width: 40)

                dottedLine

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

            // Today's steps & distance
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "shoeprints.fill")
                        .font(.appRegular(size: 14))
                        .foregroundStyle(AppColors.primaryBlueDark)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("오늘 걸음")
                            .font(.appRegular(size: 10))
                            .foregroundStyle(AppColors.textSecondary)
                        Text("\(pedometer.todaySteps.formatted()) 걸음")
                            .font(.appBold(size: 14))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppColors.primaryBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.appRegular(size: 14))
                        .foregroundStyle(AppColors.primaryBlueDark)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("오늘 이동")
                            .font(.appRegular(size: 10))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(String(format: "%.1f km", pedometer.todayDistanceKm))
                            .font(.appBold(size: 14))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppColors.accentYellow.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Divider()

            // Distance progress
            VStack(spacing: 12) {
                let todayGoalKm = dayRoute.distance / 1000.0
                let walkedKm = pedometer.todayDistanceKm
                let remaining = max(todayGoalKm - walkedKm, 0)
                let progress = todayGoalKm > 0 ? min(walkedKm / todayGoalKm, 1.0) : 0

                // Progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppColors.primaryBlueDark.opacity(0.12))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppColors.primaryBlueDark)
                                .frame(width: max(geo.size.width * progress, 0), height: 12)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text(String(format: "%.1f km", walkedKm))
                            .font(.appBold(size: 12))
                            .foregroundStyle(AppColors.primaryBlueDark)
                        Spacer()
                        Text(DistanceFormatter.formattedDetailed(dayRoute.distance))
                            .font(.appRegular(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                // Remaining + buttons
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("남은 거리")
                            .font(.appRegular(size: 11))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(String(format: "%.1f km", remaining))
                            .font(.appBold(size: 20))
                            .foregroundStyle(remaining <= 0 ? AppColors.completedGreen : .orange)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if !viewModel.isTodayCompleted {
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
                                viewModel.markCompleted(
                                    context: modelContext,
                                    totalSteps: pedometer.totalSteps,
                                    totalDistanceKm: pedometer.totalDistanceKm
                                )
                                withAnimation { showCelebration = true }
                            } label: {
                                Label("완료", systemImage: "checkmark")
                                    .font(.appBold(size: 13))
                                    .foregroundStyle(AppColors.primaryBlueDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppColors.primaryBlueDark.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        } else {
                            Button {
                                viewModel.undoCompleted(context: modelContext)
                            } label: {
                                Label("완료 취소", systemImage: "arrow.uturn.backward")
                                    .font(.appBold(size: 13))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.orange.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
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

    private var dottedLine: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            .foregroundStyle(AppColors.primaryBlueDark.opacity(0.3))
            .frame(width: 24, height: 1)
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

                // Native Ad
                if let nativeAd = adManager.nativeAd {
                    NativeAdCardView(nativeAd: nativeAd)
                }
            }
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}
