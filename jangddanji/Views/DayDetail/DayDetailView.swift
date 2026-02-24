import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var showPhotoViewer = false
    @State private var selectedPhotoIndex = 0
    @State private var isEditingPhotos = false
    @State private var draggingPhotoIndex: Int?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(dayRoute: DayRoute) {
        self.dayRoute = dayRoute
        _viewModel = State(initialValue: DayDetailViewModel(dayRoute: dayRoute))
    }

    var body: some View {
        ZStack {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                VStack(spacing: 16) {
                    mapSection
                    routeInfoCard
                    journalPhotoSection
                    journalTextSection
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
                            totalDistanceKm: pedometer.totalDistanceKm
                        )
                        if isLastSegment, let journeyID = dayRoute.journey?.id {
                            router.popToRoot()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                router.navigateTo(.journeyComplete(journeyID: journeyID))
                            }
                        } else {
                            withAnimation { showCelebration = true }
                        }
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
            endCoordinate: viewModel.endCoordinate
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

    // MARK: - Photo section

    private var journalPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("오늘의 사진")
                    .font(.appBold(size: 15))
                    .foregroundStyle(AppColors.textPrimary)
                if !journalPhotos.isEmpty {
                    Text("\(journalPhotos.count)장")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                if journalPhotos.count > 1 {
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

            if !journalPhotos.isEmpty {
                if isEditingPhotos {
                    // 순서 변경 모드: 길게 눌러 드래그
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
                    // 일반 모드: 2열 그리드
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

            // 사진 추가 버튼
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
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
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
