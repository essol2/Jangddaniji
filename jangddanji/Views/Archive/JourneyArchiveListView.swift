import SwiftUI
import SwiftData

struct JourneyArchiveListView: View {
    @Query(
        filter: #Predicate<Journey> { $0.statusRawValue == "completed" },
        sort: \Journey.endDate,
        order: .reverse
    )
    private var completedJourneys: [Journey]

    @StateObject private var adManager = NativeAdManager()
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            if completedJourneys.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(completedJourneys) { journey in
                            JourneyArchiveCard(journey: journey)
                                .onTapGesture {
                                    router.navigateTo(.archiveDetail(journeyID: journey.id))
                                }
                        }

                        // Native Ad
                        if let nativeAd = adManager.nativeAd {
                            NativeAdCardView(nativeAd: nativeAd)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
        .onAppear {
            adManager.loadAd()
        }
    }

    private var headerSection: some View {
        HStack {
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

            Spacer()

            Text("발걸음 기록")
                .font(.appBold(size: 17))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            // balance spacer
            Color.clear
                .frame(width: 60, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.clear)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.appRegular(size: 48))
                .foregroundStyle(AppColors.primaryBlueDark.opacity(0.4))
            Text("완료된 여정이 없습니다")
                .font(.appRegular(size: 16))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
    }
}

private struct JourneyArchiveCard: View {
    let journey: Journey

    private var totalCompleted: Int {
        journey.dayRoutes.filter { $0.status == .completed }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(journey.title)
                    .font(.appBold(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.appRegular(size: 18))
                    .foregroundStyle(AppColors.completedGreen)
            }

            HStack(spacing: 16) {
                Label(
                    "\(AppDateFormatter.shortDate.string(from: journey.startDate)) ~ \(AppDateFormatter.shortDate.string(from: journey.endDate))",
                    systemImage: "calendar"
                )
                .font(.appRegular(size: 12))
                .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("총 거리")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(DistanceFormatter.formattedDetailed(journey.totalDistance))
                        .font(.appBold(size: 15))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("총 일수")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(journey.numberOfDays)일")
                        .font(.appBold(size: 15))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("완주 구간")
                        .font(.appRegular(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(totalCompleted)개")
                        .font(.appBold(size: 15))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
