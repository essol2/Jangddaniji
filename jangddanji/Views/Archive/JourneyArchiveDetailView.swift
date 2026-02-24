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
    @State private var showPhotoViewer = false
    @State private var viewerPhotos: [Data] = []
    @State private var viewerIndex = 0

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection

                    VStack(spacing: 12) {
                        summaryCard

                        Text("여정 기록")
                            .font(.appBold(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)

                        ForEach(journey.sortedDayRoutes) { dayRoute in
                            ArchiveDayCard(dayRoute: dayRoute) { photos, index in
                                viewerPhotos = photos
                                viewerIndex = index
                                withAnimation { showPhotoViewer = true }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppColors.background)
            .navigationBarHidden(true)

            if showPhotoViewer {
                ArchivePhotoViewerOverlay(
                    photos: viewerPhotos,
                    currentIndex: $viewerIndex,
                    isPresented: $showPhotoViewer
                )
                .transition(.opacity)
            }
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

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(journey.title)
                        .font(.appBold(size: 24))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(AppDateFormatter.shortDate.string(from: journey.startDate)) ~ \(AppDateFormatter.shortDate.string(from: journey.endDate))")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.appRegular(size: 28))
                    .foregroundStyle(AppColors.completedGreen)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: 10) {
            // 상단 3개: 총 거리, 총 일수, 완주 구간
            HStack(spacing: 10) {
                StatCard(
                    icon: "map.fill",
                    value: DistanceFormatter.formattedDetailed(journey.totalDistance),
                    label: "총 거리",
                    tint: AppColors.primaryBlueDark
                )
                StatCard(
                    icon: "calendar",
                    value: "\(journey.numberOfDays)일",
                    label: "총 일수",
                    tint: .orange
                )
                StatCard(
                    icon: "flag.fill",
                    value: "\(journey.dayRoutes.filter { $0.status == .completed }.count)구간",
                    label: "완주",
                    tint: AppColors.completedGreen
                )
            }

            // 하단 2개: 총 걸음, 총 이동
            HStack(spacing: 10) {
                StatCard(
                    icon: "shoeprints.fill",
                    value: journey.totalSteps.formatted(),
                    label: "총 걸음",
                    tint: .purple
                )
                StatCard(
                    icon: "figure.walk",
                    value: String(format: "%.1f km", journey.totalDistanceWalked),
                    label: "총 이동",
                    tint: .blue
                )
            }
        }
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            Text(value)
                .font(.appBold(size: 16))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.appRegular(size: 11))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - Day card

private struct ArchiveDayCard: View {
    let dayRoute: DayRoute
    var onPhotoTap: ([Data], Int) -> Void
    @State private var isExpanded = false

    private var hasJournal: Bool {
        guard let entry = dayRoute.journalEntry else { return false }
        return !entry.text.isEmpty || entry.hasAnyPhoto
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
                            .font(.appRegular(size: 9))
                            .foregroundStyle(AppColors.textSecondary)
                        Text("\(dayRoute.dayNumber)")
                            .font(.appBold(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .frame(width: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppDateFormatter.dayMonth.string(from: dayRoute.date))
                            .font(.appRegular(size: 12))
                            .foregroundStyle(AppColors.textSecondary)

                        HStack(spacing: 4) {
                            Text(dayRoute.startLocationName)
                                .font(.appRegular(size: 13))
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.appRegular(size: 10))
                                .foregroundStyle(AppColors.textSecondary)
                            Text(dayRoute.endLocationName)
                                .font(.appRegular(size: 13))
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppColors.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(DistanceFormatter.formattedDetailed(dayRoute.distance))
                            .font(.appBold(size: 12))
                            .foregroundStyle(AppColors.textPrimary)

                        if hasJournal {
                            Image(systemName: "pencil.line")
                                .font(.appRegular(size: 12))
                                .foregroundStyle(AppColors.primaryBlueDark)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.appRegular(size: 12))
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
                    if !entry.sortedPhotos.isEmpty {
                        let photosData = entry.sortedPhotos.map(\.photoData)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(entry.sortedPhotos.enumerated()), id: \.element.id) { index, photo in
                                    if let uiImage = UIImage(data: photo.photoData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 200, height: 150)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture {
                                                onPhotoTap(photosData, index)
                                            }
                                    }
                                }
                            }
                        }
                    }

                    if !entry.text.isEmpty {
                        Text(entry.text)
                            .font(.appRegular(size: 14))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if entry.text.isEmpty && !entry.hasAnyPhoto {
                        Text("기록이 없습니다")
                            .font(.appRegular(size: 13))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else if isExpanded && !hasJournal {
                Divider()
                    .padding(.horizontal, 14)

                Text("기록이 없습니다")
                    .font(.appRegular(size: 13))
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

// MARK: - Archive Photo Viewer Overlay

private struct ArchivePhotoViewerOverlay: View {
    let photos: [Data]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                    if let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))

            VStack {
                HStack {
                    if photos.count > 1 {
                        Text("\(currentIndex + 1) / \(photos.count)")
                            .font(.appBold(size: 15))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.appBold(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()
            }
        }
    }
}
