import SwiftUI
import MapKit
import PhotosUI
import SwiftData

struct HikingResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var journalText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []
    @State private var isSaving = false

    let journeyID: UUID

    private var journey: Journey? {
        let id = journeyID
        let descriptor = FetchDescriptor<Journey>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private var dayRoute: DayRoute? {
        journey?.sortedDayRoutes.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                mapSnapshotCard
                journalCard
                photoCard
                saveButton
            }
            .padding(20)
        }
        .background(AppColors.background)
        .navigationTitle("등산 완료")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "mountain.2.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.primaryBlueDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text(journey?.title ?? "")
                        .font(.appBold(size: 20))
                        .foregroundStyle(AppColors.textPrimary)
                    if let date = journey?.startDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.appRegular(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.primaryBlue)
            }

            Divider()

            HStack(spacing: 0) {
                summaryStatItem(
                    icon: "clock.fill",
                    value: formattedDuration,
                    label: "소요 시간",
                    color: .blue
                )
                Divider().frame(height: 44)
                summaryStatItem(
                    icon: "figure.walk",
                    value: "\(journey?.totalSteps ?? 0)",
                    label: "걸음수",
                    color: .green
                )
                Divider().frame(height: 44)
                summaryStatItem(
                    icon: "map.fill",
                    value: String(format: "%.2f km", journey?.totalDistanceWalked ?? 0),
                    label: "이동 거리",
                    color: AppColors.primaryBlueDark
                )
                Divider().frame(height: 44)
                summaryStatItem(
                    icon: "flame.fill",
                    value: "—",
                    label: "칼로리",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func summaryStatItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
            Text(value)
                .font(.appBold(size: 14))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.appRegular(size: 11))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map Snapshot

    @ViewBuilder
    private var mapSnapshotCard: some View {
        if let route = dayRoute, !route.waypointCoordinates.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("이동 경로")
                    .font(.appBold(size: 16))
                    .foregroundStyle(AppColors.textPrimary)

                HikingRouteMapView(coordinates: route.waypointCoordinates)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Journal Card

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("오늘의 등산 메모")
                    .font(.appBold(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
            }

            TextEditor(text: $journalText)
                .font(.appRegular(size: 15))
                .frame(minHeight: 100)
                .padding(8)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Photo Card

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(AppColors.primaryBlueDark)
                Text("사진")
                    .font(.appBold(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                    Text("추가")
                        .font(.appBold(size: 14))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }
                .onChange(of: selectedPhotos) {
                    loadPhotos()
                }
            }

            if photoDataList.isEmpty {
                Text("사진을 추가해보세요")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photoDataList.enumerated()), id: \.offset) { index, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveJournal()
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(isSaving ? "저장 중..." : "저장하기")
                    .font(.appBold(size: 17))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppColors.primaryBlueDark)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isSaving)
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        guard let journey = journey else { return "—" }
        let seconds = Int(journey.endDate.timeIntervalSince(journey.startDate))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)시간 \(m)분" }
        return "\(m)분"
    }

    private func loadPhotos() {
        Task {
            var loaded: [Data] = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(data)
                }
            }
            photoDataList = loaded
        }
    }

    private func saveJournal() {
        guard let route = dayRoute else {
            router.popToRoot()
            return
        }

        isSaving = true

        if !journalText.trimmingCharacters(in: .whitespaces).isEmpty || !photoDataList.isEmpty {
            let entry = JournalEntry(text: journalText)
            entry.dayRoute = route
            context.insert(entry)

            for (index, data) in photoDataList.enumerated() {
                let photo = JournalPhoto(photoData: data, sortOrder: index)
                photo.journalEntry = entry
                context.insert(photo)
            }
        }

        try? modelContext.save()
        isSaving = false
        router.popToRoot()
    }

    private var context: ModelContext { modelContext }
}

// MARK: - Route Map View

private struct HikingRouteMapView: View {
    let coordinates: [WaypointCoordinate]

    private var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var region: MKCoordinateRegion {
        guard !clCoordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5, longitude: 127.0),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        let lats = clCoordinates.map { $0.latitude }
        let lons = clCoordinates.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.4 + 0.002,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.4 + 0.002
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            if clCoordinates.count >= 2 {
                MapPolyline(coordinates: clCoordinates)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
            }
            if let first = clCoordinates.first {
                Annotation("출발", coordinate: first) {
                    Circle().fill(.green).frame(width: 12, height: 12)
                }
            }
            if let last = clCoordinates.last {
                Annotation("도착", coordinate: last) {
                    Circle().fill(.red).frame(width: 12, height: 12)
                }
            }
        }
        .disabled(true)  // 인터랙션 비활성화
    }
}
