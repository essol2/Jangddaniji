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
    @State private var journalPhotoData: Data?
    @State private var showMapAppPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(dayRoute: DayRoute) {
        self.dayRoute = dayRoute
        _viewModel = State(initialValue: DayDetailViewModel(dayRoute: dayRoute))
    }

    var body: some View {
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
        .navigationBarHidden(true)
        .onAppear {
            journalText = viewModel.initialText
            journalPhotoData = viewModel.initialPhotoData
        }
        .onChange(of: journalText) { _, newText in
            viewModel.scheduleSave(text: newText, photoData: journalPhotoData, context: modelContext)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                guard let newItem else {
                    journalPhotoData = nil
                    viewModel.saveJournal(text: journalText, photoData: nil, context: modelContext)
                    return
                }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let compressed = DayDetailViewModel.compressImage(uiImage) {
                    journalPhotoData = compressed
                    viewModel.saveJournal(text: journalText, photoData: compressed, context: modelContext)
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
                    viewModel.openDirections(with: app)
                }
            }
            Button("취소", role: .cancel) {}
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
                        viewModel.markCompleted(context: modelContext)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.appBold(size: 15))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(AppColors.primaryBlueDark)
                            .clipShape(Circle())
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
            Text("오늘의 사진")
                .font(.appBold(size: 15))
                .foregroundStyle(AppColors.textPrimary)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let photoData = journalPhotoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.appRegular(size: 28))
                                .foregroundStyle(AppColors.primaryBlueDark)
                                .padding(8)
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.08))
                            .frame(height: 120)
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.appRegular(size: 28))
                                .foregroundStyle(AppColors.primaryBlueDark.opacity(0.6))
                            Text("사진 추가")
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
