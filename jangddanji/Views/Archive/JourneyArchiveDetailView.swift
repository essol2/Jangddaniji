import SwiftUI
import SwiftData

struct JourneyArchiveDetailView: View {
    let journeyID: UUID
    @Query private var journeys: [Journey]

    init(journeyID: UUID) {
        self.journeyID = journeyID
        _journeys = Query(filter: #Predicate<Journey> { $0.id == journeyID })
    }

    var body: some View {
        if let journey = journeys.first {
            ArchiveDetailContentView(journey: journey)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
        }
    }
}

private struct ArchiveDetailContentView: View {
    let journey: Journey
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                VStack(spacing: 12) {
                    summaryCard

                    Text("여정 기록")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    ForEach(journey.sortedDayRoutes) { dayRoute in
                        ArchiveDayCard(dayRoute: dayRoute)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            .padding(.bottom, 4)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(journey.title)
                        .font(.jejuDoldam(size: 24))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(AppDateFormatter.shortDate.string(from: journey.startDate)) ~ \(AppDateFormatter.shortDate.string(from: journey.endDate))")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.completedGreen)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.headerGradient)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        HStack {
            Spacer()
            statItem(value: DistanceFormatter.formattedDetailed(journey.totalDistance), label: "총 거리")
            Spacer()
            Divider().frame(height: 40)
            Spacer()
            statItem(value: "\(journey.numberOfDays)일", label: "총 일수")
            Spacer()
            Divider().frame(height: 40)
            Spacer()
            statItem(value: "\(journey.dayRoutes.filter { $0.status == .completed }.count)구간", label: "완주")
            Spacer()
        }
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.primaryBlueDark)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Day card

private struct ArchiveDayCard: View {
    let dayRoute: DayRoute
    @State private var isExpanded = false

    private var hasJournal: Bool {
        guard let entry = dayRoute.journalEntry else { return false }
        return !entry.text.isEmpty || entry.photoData != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Day badge
                    VStack(spacing: 1) {
                        Text("Day")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Text("\(dayRoute.dayNumber)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .frame(width: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppDateFormatter.dayMonth.string(from: dayRoute.date))
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)

                        HStack(spacing: 4) {
                            Text(dayRoute.startLocationName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.textSecondary)
                            Text(dayRoute.endLocationName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppColors.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(DistanceFormatter.formattedDetailed(dayRoute.distance))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)

                        if hasJournal {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.primaryBlueDark)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Journal content (expanded)
            if isExpanded, let entry = dayRoute.journalEntry {
                Divider()
                    .padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 12) {
                    if let photoData = entry.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if !entry.text.isEmpty {
                        Text(entry.text)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if entry.text.isEmpty && entry.photoData == nil {
                        Text("기록이 없습니다")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else if isExpanded && !hasJournal {
                Divider()
                    .padding(.horizontal, 14)

                Text("기록이 없습니다")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}
