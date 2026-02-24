import SwiftUI
import SwiftData

struct JourneyCompleteView: View {
    let journeyID: UUID
    @Query private var journeys: [Journey]

    init(journeyID: UUID) {
        self.journeyID = journeyID
        _journeys = Query(filter: #Predicate<Journey> { $0.id == journeyID })
    }

    var body: some View {
        if let journey = journeys.first {
            JourneyCompleteContentView(journey: journey)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
        }
    }
}

private struct JourneyCompleteContentView: View {
    let journey: Journey
    @Environment(AppRouter.self) private var router

    @State private var trophyScale: Double = 0.3
    @State private var trophyOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var particles: [ConfettiDot] = []

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            // Confetti
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .position(p.position)
                    .opacity(p.opacity)
            }

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Trophy
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(trophyScale)
                        .opacity(trophyOpacity)

                    Spacer().frame(height: 20)

                    VStack(spacing: 8) {
                        Text("국토종주 완료!")
                            .font(.appBold(size: 28))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("축하합니다! 대장정을 완주했습니다")
                            .font(.appRegular(size: 15))
                            .foregroundStyle(AppColors.textSecondary)

                        Text(journey.title)
                            .font(.appBold(size: 16))
                            .foregroundStyle(AppColors.primaryBlueDark)
                            .padding(.top, 4)
                    }
                    .opacity(contentOpacity)

                    Spacer().frame(height: 32)

                    // Stats grid
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            completeStatCard(
                                icon: "shoeprints.fill",
                                value: journey.totalSteps.formatted(),
                                label: "총 걸음",
                                tint: .purple
                            )
                            completeStatCard(
                                icon: "figure.walk",
                                value: String(format: "%.1f km", journey.totalDistanceWalked),
                                label: "총 이동 거리",
                                tint: .blue
                            )
                        }

                        HStack(spacing: 12) {
                            completeStatCard(
                                icon: "calendar",
                                value: "\(journey.numberOfDays)일",
                                label: "총 일수",
                                tint: .orange
                            )
                            completeStatCard(
                                icon: "flag.fill",
                                value: "\(journey.dayRoutes.count)구간",
                                label: "완주 구간",
                                tint: AppColors.completedGreen
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(contentOpacity)

                    Spacer().frame(height: 40)

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            router.popToRoot()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                router.navigateTo(.archiveDetail(journeyID: journey.id))
                            }
                        } label: {
                            Text("여정 기록 보기")
                                .font(.appBold(size: 16))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(AppColors.primaryBlueDark)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            router.popToRoot()
                        } label: {
                            Text("처음으로")
                                .font(.appBold(size: 16))
                                .foregroundStyle(AppColors.primaryBlueDark)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(AppColors.primaryBlueDark.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(contentOpacity)

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            spawnConfetti()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                trophyScale = 1.0
                trophyOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                contentOpacity = 1.0
            }
        }
    }

    private func completeStatCard(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            Text(value)
                .font(.appBold(size: 20))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.appRegular(size: 12))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func spawnConfetti() {
        let colors: [Color] = [
            AppColors.primaryBlue, AppColors.primaryBlueDark,
            AppColors.accentYellow, .orange, .pink, .purple, .yellow
        ]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        for i in 0..<60 {
            let startX = CGFloat.random(in: 0...screenWidth)
            let startY = CGFloat.random(in: -80...screenHeight * 0.2)
            let endY = screenHeight + 80
            let size = CGFloat.random(in: 6...16)
            let delay = Double(i) * 0.025

            let dot = ConfettiDot(
                id: i,
                color: colors.randomElement()!,
                size: size,
                position: CGPoint(x: startX, y: startY),
                opacity: 1
            )
            particles.append(dot)

            let index = particles.count - 1
            let driftX = CGFloat.random(in: -80...80)

            withAnimation(
                .easeIn(duration: Double.random(in: 2.5...4.0)).delay(delay)
            ) {
                particles[index].position = CGPoint(x: startX + driftX, y: endY)
                particles[index].opacity = 0
            }
        }
    }
}

private struct ConfettiDot: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}
