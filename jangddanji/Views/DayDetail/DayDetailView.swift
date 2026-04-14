import SwiftUI
import SwiftData
import PhotosUI
import AVKit

struct DayDetailView: View {
    let dayRouteID: UUID
    @Query private var dayRoutes: [DayRoute]

    init(dayRouteID: UUID) {
        self.dayRouteID = dayRouteID
        _dayRoutes = Query(filter: #Predicate<DayRoute> { $0.id == dayRouteID })
    }

    var body: some View {
        if let dayRoute = dayRoutes.first {
            DayDetailContentView(dayRoute: dayRoute)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
        }
    }
}

private struct DayDetailContentView: View {
    let dayRoute: DayRoute
    @State private var viewModel: DayDetailViewModel
    @State private var journalText = ""
    @State private var journalPhotos: [Data] = []
    @State private var showMapAppPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var pedometer = PedometerService()
    @State private var showCelebration = false
    @State private var pendingJourneyCompleteID: UUID? = nil
    @State private var showPhotoViewer = false
    @State private var selectedPhotoIndex = 0
    @State private var isEditingPhotos = false
    @State private var draggingPhotoIndex: Int?
    @State private var isExportingVideo = false
    @State private var notificationStartHour: Int
    @State private var notificationEndHour: Int
    @State private var selectedMediaTab: MediaTab = .photo

    private enum MediaTab: String, CaseIterable {
        case photo = "사진"
        case video = "영상"
    }
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(dayRoute: DayRoute) {
        self.dayRoute = dayRoute
        _viewModel = State(initialValue: DayDetailViewModel(dayRoute: dayRoute))
        _notificationStartHour = State(initialValue: dayRoute.diaryNotificationStartHour)
        _notificationEndHour = State(initialValue: dayRoute.diaryNotificationEndHour)
    }

    var body: some View {
        ZStack {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                VStack(spacing: 16) {
                    mapSection
                    routeInfoCard
                    mediaSection
                    journalTextSection
                    if !viewModel.isCompleted {
                        diaryNotificationSettingSection
                    }
                }
                .padding(16)
            }
        }
        .background(AppColors.background)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationBarHidden(true)
        .onAppear {
            journalText = viewModel.initialText
            journalPhotos = viewModel.initialPhotos
            if let journey = dayRoute.journey {
                pedometer.setPeriodStart(journey.startDate)
            }
            pedometer.requestAuthorization()
        }
        .onChange(of: journalText) { _, newText in
            viewModel.scheduleSaveText(newText, context: modelContext)
        }
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var newPhotosData: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let compressed = DayDetailViewModel.compressImage(uiImage) {
                        newPhotosData.append(compressed)
                    }
                }
                if !newPhotosData.isEmpty {
                    journalPhotos.append(contentsOf: newPhotosData)
                    viewModel.addPhotos(newPhotosData, context: modelContext)
                }
                selectedPhotos = []
            }
        }
        .confirmationDialog(
            "길찾기 앱 선택",
            isPresented: $showMapAppPicker,
            titleVisibility: .visible
        ) {
            ForEach(viewModel.availableMapApps) { app in
                Button(app.rawValue) {
                    viewModel.openDirections(with: app)
                }
            }
            Button("취소", role: .cancel) {}
        }

            if showCelebration {
                CelebrationOverlayView(
                    steps: pedometer.todaySteps,
                    distanceKm: pedometer.todayDistanceKm,
                    isPresented: $showCelebration
                )
                .transition(.opacity)
            }

            if showPhotoViewer {
                PhotoViewerOverlay(
                    photos: journalPhotos,
                    currentIndex: $selectedPhotoIndex,
                    isPresented: $showPhotoViewer
                )
                .transition(.opacity)
            }
        } // ZStack
        .onChange(of: showCelebration) { _, isShowing in
            guard !isShowing, let journeyID = pendingJourneyCompleteID else { return }
            pendingJourneyCompleteID = nil
            router.popToRoot()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                router.navigateTo(.journeyComplete(journeyID: journeyID))
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
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

                if viewModel.canComplete {
                    Button {
                        let isLastSegment = viewModel.isLastSegment
                        viewModel.markCompleted(
                            context: modelContext,
                            totalSteps: pedometer.totalSteps,
                            totalDistanceKm: pedometer.totalDistanceKm,
                            daySteps: pedometer.todaySteps,
                            dayDistanceKm: pedometer.todayDistanceKm
                        )
                        if isLastSegment, let journeyID = dayRoute.journey?.id {
                            pendingJourneyCompleteID = journeyID
                        }
                        DiaryNotificationService.shared.cancelNotifications(for: dayRoute.id)
                        triggerVideoExportIfNeeded()
                        withAnimation { showCelebration = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.appBold(size: 13))
                            Text("완료")
                                .font(.appBold(size: 13))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.primaryBlueDark)
                        .clipShape(Capsule())
                    }
                // DEBUG: 모든 날짜에서 완료 취소 가능 (배포 시 viewModel.isCompleted && viewModel.isTodayRoute 로 변경)
                } else if viewModel.isCompleted {
                    Button {
                        viewModel.undoCompleted(context: modelContext)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.appBold(size: 13))
                            Text("완료 취소")
                                .font(.appBold(size: 13))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.bottom, 4)

            Text("Day \(dayRoute.dayNumber)")
                .font(.appBold(size: 28))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 4) {
                Text(dayRoute.startLocationName)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.appRegular(size: 11))
                Text(dayRoute.endLocationName)
                    .lineLimit(1)
            }
            .font(.appRegular(size: 14))
            .foregroundStyle(AppColors.textSecondary)

            Text(AppDateFormatter.dayMonth.string(from: dayRoute.date))
                .font(.appRegular(size: 13))
                .foregroundStyle(AppColors.textSecondary.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
    }

    // MARK: - Map

    private var mapSection: some View {
        MapSnippetView(
            startCoordinate: viewModel.startCoordinate,
            endCoordinate: viewModel.endCoordinate,
            waypoints: viewModel.waypoints
        )
        .frame(height: 180)
    }

    // MARK: - Route info card

    private var routeInfoCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Label(DistanceFormatter.formattedDetailed(dayRoute.distance), systemImage: "figure.walk")
                    .font(.appBold(size: 16))
                    .foregroundStyle(AppColors.textPrimary)

                statusBadge
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    showMapAppPicker = true
                } label: {
                    Label("길찾기", systemImage: "map.fill")
                        .font(.appBold(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.primaryBlueDark)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    router.navigateTo(.routeModify(dayRouteID: dayRoute.id))
                } label: {
                    Label("경로 수정", systemImage: "pencil")
                        .font(.appBold(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch dayRoute.status {
            case .completed: return ("완료", AppColors.completedGreen)
            case .today: return ("오늘", AppColors.primaryBlueDark)
            case .upcoming: return ("예정", Color.gray)
            case .skipped: return ("건너뜀", .orange)
            }
        }()

        return Text(text)
            .font(.appBold(size: 12))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func deletePhoto(at index: Int) {
        guard index < journalPhotos.count else { return }
        journalPhotos.remove(at: index)
        if let entry = dayRoute.journalEntry {
            let sorted = entry.sortedPhotos
            if index < sorted.count {
                viewModel.deletePhoto(sorted[index], context: modelContext)
            }
        }
    }

    // MARK: - Media section (사진 + 영상 통합)

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 탭 헤더
            HStack {
                Picker("미디어", selection: $selectedMediaTab) {
                    ForEach(MediaTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if selectedMediaTab == .photo, !journalPhotos.isEmpty {
                    Text("\(journalPhotos.count)장")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }

                if selectedMediaTab == .photo, journalPhotos.count > 1 {
                    Button {
                        withAnimation { isEditingPhotos.toggle() }
                    } label: {
                        Text(isEditingPhotos ? "완료" : "순서 변경")
                            .font(.appBold(size: 12))
                            .foregroundStyle(isEditingPhotos ? .white : AppColors.primaryBlueDark)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isEditingPhotos ? AppColors.primaryBlueDark : AppColors.primaryBlueDark.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            // 탭 콘텐츠
            if selectedMediaTab == .photo {
                photoContent
            } else {
                videoContent
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Photo content

    private var photoContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !journalPhotos.isEmpty {
                if isEditingPhotos {
                    VStack(spacing: 8) {
                        ForEach(Array(journalPhotos.enumerated()), id: \.offset) { index, photoData in
                            if let uiImage = UIImage(data: photoData) {
                                HStack(spacing: 12) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Text("\(index + 1)번째 사진")
                                        .font(.appRegular(size: 13))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Spacer()
                                }
                                .padding(8)
                                .background(draggingPhotoIndex == index
                                    ? AppColors.primaryBlueDark.opacity(0.08)
                                    : Color.gray.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onDrag {
                                    draggingPhotoIndex = index
                                    return NSItemProvider(object: "\(index)" as NSString)
                                }
                                .onDrop(of: [.text], delegate: PhotoDropDelegate(
                                    destinationIndex: index,
                                    photos: $journalPhotos,
                                    draggingIndex: $draggingPhotoIndex,
                                    onReorder: {
                                        viewModel.reorderPhotos(journalPhotos, context: modelContext)
                                    }
                                ))
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(Array(journalPhotos.enumerated()), id: \.offset) { index, photoData in
                            if let uiImage = UIImage(data: photoData) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 120)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .contentShape(RoundedRectangle(cornerRadius: 10))
                                        .onTapGesture {
                                            selectedPhotoIndex = index
                                            withAnimation { showPhotoViewer = true }
                                        }
                                    Button {
                                        deletePhoto(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                            .padding(4)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if !isEditingPhotos {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.08))
                            .frame(height: journalPhotos.isEmpty ? 120 : 52)
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.appRegular(size: journalPhotos.isEmpty ? 28 : 18))
                                .foregroundStyle(AppColors.primaryBlueDark.opacity(0.6))
                            Text(journalPhotos.isEmpty ? "사진 추가" : "사진 더 추가")
                                .font(.appRegular(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Video content

    private var videoContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dayRoute.diaryClipPaths.isEmpty {
                Text("아직 촬영된 클립이 없습니다")
                    .font(.appRegular(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dayRoute.diaryClipPaths, id: \.self) { path in
                            let url = URL(fileURLWithPath: path)
                            let hour = Int(url.deletingPathExtension().lastPathComponent) ?? 0
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black)
                                    .frame(width: 72, height: 96)
                                    .overlay {
                                        Image(systemName: "video.fill")
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                Text(String(format: "%02d:00", hour))
                                    .font(.appRegular(size: 11))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }

            if isExportingVideo {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("영상 생성 중...")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else if let videoPath = dayRoute.diaryVideoPath {
                Button {
                    router.navigateTo(.diaryPlayer(videoPath: videoPath))
                } label: {
                    Label("영상 보러가기", systemImage: "play.circle.fill")
                        .font(.appBold(size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.primaryBlueDark)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Diary notification setting section

    private var diaryNotificationSettingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("영상 촬영 알림")
                .font(.appBold(size: 15))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 6) {
                Picker("시작", selection: $notificationStartHour) {
                    ForEach(0...23, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: notificationStartHour) { _, newValue in
                    if newValue >= notificationEndHour {
                        notificationEndHour = min(newValue + 1, 23)
                    }
                    saveNotificationSettings()
                }

                Image(systemName: "arrow.right")
                    .font(.appRegular(size: 12))
                    .foregroundStyle(AppColors.textSecondary)

                Picker("종료", selection: $notificationEndHour) {
                    ForEach(0...23, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: notificationEndHour) { _, newValue in
                    if newValue <= notificationStartHour {
                        notificationStartHour = max(newValue - 1, 0)
                    }
                    saveNotificationSettings()
                }

                Spacer()
            }

            Text("매 정시마다 알림을 보내드려요")
                .font(.appRegular(size: 12))
                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.bottom, 16)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "오전 12시" }
        if hour < 12 { return "오전 \(hour)시" }
        if hour == 12 { return "오후 12시" }
        return "오후 \(hour - 12)시"
    }

    private func saveNotificationSettings() {
        dayRoute.diaryNotificationStartHour = notificationStartHour
        dayRoute.diaryNotificationEndHour = notificationEndHour
        try? modelContext.save()
        DiaryNotificationService.shared.scheduleHourlyNotifications(
            for: dayRoute.id,
            startHour: notificationStartHour,
            endHour: notificationEndHour
        )
    }

    private func triggerVideoExportIfNeeded() {
        let paths = dayRoute.diaryClipPaths
        guard !paths.isEmpty else { return }
        isExportingVideo = true
        let id = dayRoute.id
        Task {
            do {
                let videoPath = try await DiaryVideoService.shared.exportDiaryVideo(
                    clipPaths: paths,
                    dayRouteID: id
                )
                await MainActor.run {
                    dayRoute.diaryVideoPath = videoPath
                    try? modelContext.save()
                    isExportingVideo = false
                }
            } catch {
                await MainActor.run { isExportingVideo = false }
            }
        }
    }

    // MARK: - Journal text section

    private var journalTextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("오늘의 기록")
                .font(.appBold(size: 15))
                .foregroundStyle(AppColors.textPrimary)

            ZStack(alignment: .topLeading) {
                if journalText.isEmpty {
                    Text("오늘 하루를 기록해보세요...")
                        .font(.appRegular(size: 14))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $journalText)
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.bottom, 32)
    }
}

// MARK: - Photo Drop Delegate

private struct PhotoDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var photos: [Data]
    @Binding var draggingIndex: Int?
    var onReorder: () -> Void

    func dropEntered(info: DropInfo) {
        guard let from = draggingIndex, from != destinationIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            photos.move(fromOffsets: IndexSet(integer: from), toOffset: destinationIndex > from ? destinationIndex + 1 : destinationIndex)
        }
        draggingIndex = destinationIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingIndex = nil
        onReorder()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Photo Viewer Overlay

private struct PhotoViewerOverlay: View {
    let photos: [Data]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 스와이프로 사진 전환
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

            // 닫기 버튼 + 카운터
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
