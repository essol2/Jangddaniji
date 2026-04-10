import SwiftUI
import SwiftData

struct EntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Journey> { $0.statusRawValue == "active" && $0.journeyType == "longDistance" })
    private var activeJourneys: [Journey]
    @Query(filter: #Predicate<Journey> { $0.statusRawValue == "active" && $0.journeyType == "hiking" })
    private var activeHikings: [Journey]
    @Query(filter: #Predicate<Journey> { $0.statusRawValue == "completed" })
    private var completedJourneys: [Journey]

    // [AD-DISABLED] private var interstitialAd = InterstitialAdManager.shared

    var body: some View {
        ZStack {
            AppColors.entryGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo icon
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.9))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.appRegular(size: 36))
                            .foregroundStyle(AppColors.primaryBlueDark)
                    }
                    .padding(.bottom, 20)

                // App name
                Text("장딴지")
                    .font(.appBold(size: 36))
                    .foregroundStyle(.white)

                // Tagline
                Text("당신의 장거리 단짝 지도")
                    .font(.appBold(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)

                Spacer()

                // Motivational text
                VStack(spacing: 2) {
                    Text("한 걸음 한 걸음이 모여")
                    Text("위대한 여정을 만듭니다")
                }
                .font(.appBold(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 24)

                // Buttons
                VStack(spacing: 12) {
                    if !activeJourneys.isEmpty {
                        Button {
                                router.navigateTo(.dashboard)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.walk.circle.fill")
                                    .font(.appRegular(size: 18))
                                Text("진행 중인 발걸음")
                                    .font(.appBold(size: 17))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColors.primaryBlueDark)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        Button {
                                router.navigateTo(.planning)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.appRegular(size: 18))
                                Text("새로운 발걸음")
                                    .font(.appBold(size: 17))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColors.primaryBlueDark)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    // 등산 버튼
                    if !activeHikings.isEmpty {
                        Button {
                            if let hiking = activeHikings.first,
                               let route = hiking.sortedDayRoutes.first {
                                router.navigateTo(.hikingTracking(
                                    mountainName: hiking.title,
                                    latitude: route.startLatitude,
                                    longitude: route.startLongitude
                                ))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.hiking")
                                    .font(.appRegular(size: 18))
                                Text("이어서 등산하기")
                                    .font(.appBold(size: 17))
                            }
                            .foregroundStyle(AppColors.primaryBlueDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        Button {
                            router.navigateTo(.hikingSetup)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.hiking")
                                    .font(.appRegular(size: 18))
                                Text("등산 기록하기")
                                    .font(.appBold(size: 17))
                            }
                            .foregroundStyle(AppColors.primaryBlueDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    if !completedJourneys.isEmpty {
                        Button {
                            router.navigateTo(.archiveList)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                    .font(.appRegular(size: 18))
                                Text("이전 발걸음")
                                    .font(.appBold(size: 17))
                            }
                            .foregroundStyle(AppColors.primaryBlueDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    Button {
                        router.navigateTo(.backup)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "icloud.fill")
                                .font(.appRegular(size: 18))
                            Text("iCloud 백업")
                                .font(.appBold(size: 17))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 40)

                // Copyright
                Text("\u{00A9} 2026 Jangddanji. All rights reserved.")
                    .font(.appRegular(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
    }
}
