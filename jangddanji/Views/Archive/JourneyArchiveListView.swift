import SwiftUI
import SwiftData

struct JourneyArchiveListView: View {
    @Query(
        filter: #Predicate<Journey> { $0.statusRawValue == "completed" },
        sort: \Journey.endDate,
        order: .reverse
    )
    private var completedJourneys: [Journey]

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
                    }
                    .padding(16)
                }
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
    }

    private var headerSection: some View {
        HStack {
            Button {
                router.pop()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("뒤로")
                        .font(.system(size: 15))
                }
                .foregroundStyle(AppColors.primaryBlueDark)
            }

            Spacer()

            Text("발걸음 기록")
                .font(.jejuDoldam(size: 17))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            // balance spacer
            Color.clear
                .frame(width: 60, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.headerGradient)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.primaryBlueDark.opacity(0.4))
            Text("완료된 여정이 없습니다")
                .font(.system(size: 16))
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
                    .font(.jejuDoldam(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.completedGreen)
            }

            HStack(spacing: 16) {
                Label(
                    "\(AppDateFormatter.shortDate.string(from: journey.startDate)) ~ \(AppDateFormatter.shortDate.string(from: journey.endDate))",
                    systemImage: "calendar"
                )
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("총 거리")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(DistanceFormatter.formattedDetailed(journey.totalDistance))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("총 일수")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(journey.numberOfDays)일")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("완주 구간")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(totalCompleted)개")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
