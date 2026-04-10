import SwiftUI
import MapKit
import CoreLocation

struct HikingTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var viewModel: HikingTrackingViewModel
    @State private var showCompleteConfirm = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    init(mountainName: String, latitude: Double, longitude: Double) {
        _viewModel = State(initialValue: HikingTrackingViewModel(
            mountainName: mountainName,
            latitude: latitude,
            longitude: longitude
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapView

            VStack(spacing: 0) {
                backgroundBanner
                Spacer()
                statsCard
            }
        }
        .navigationTitle(viewModel.mountainName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCompleteConfirm = true
                } label: {
                    Text("완료")
                        .font(.appBold(size: 16))
                        .foregroundStyle(AppColors.primaryBlueDark)
                }
            }
        }
        .alert("미완료 등산 세션 발견", isPresented: $viewModel.showRecoveryAlert) {
            Button("이어서 기록") { viewModel.resumeSavedSession() }
            Button("새로 시작", role: .destructive) { viewModel.discardSavedSession() }
        } message: {
            Text("'\(viewModel.recoveredMountainName)' 등산 기록이 남아있습니다. 이어서 기록할까요?")
        }
        .alert("등산 완료", isPresented: $showCompleteConfirm) {
            Button("완료", role: .destructive) { finishHiking() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("등산을 완료하고 기록을 저장할까요?")
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.coordinates.count) {
            guard let loc = viewModel.currentLocation else { return }
            cameraPosition = .region(MKCoordinateRegion(
                center: loc,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $cameraPosition) {
            // 현재 위치 마커
            if let location = viewModel.currentLocation {
                Annotation("현재 위치", coordinate: location) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primaryBlueDark)
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                    }
                    .shadow(radius: 3)
                }
            }

            // 경로 폴리라인
            if viewModel.coordinates.count >= 2 {
                MapPolyline(coordinates: viewModel.coordinates)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Background Banner

    @ViewBuilder
    private var backgroundBanner: some View {
        if viewModel.authorizationStatus == .authorizedAlways {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                    .font(.caption)
                Text("화면이 꺼지면 경로 기록이 중단될 수 있습니다. 설정에서 '항상 허용'으로 변경하세요.")
                    .font(.appRegular(size: 12))
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.9))
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 16) {
            // 경과 시간
            Text(formattedElapsedTime)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)

            // 통계 그리드
            HStack(spacing: 0) {
                statItem(
                    icon: "figure.walk",
                    value: "\(viewModel.steps)",
                    unit: "걸음"
                )
                Divider().frame(height: 40)
                statItem(
                    icon: "map",
                    value: String(format: "%.2f", viewModel.distanceKm),
                    unit: "km"
                )
                Divider().frame(height: 40)
                statItem(
                    icon: "flame.fill",
                    value: String(format: "%.0f", viewModel.calories),
                    unit: "kcal"
                )
                Divider().frame(height: 40)
                statItem(
                    icon: "location.fill",
                    value: String(format: "%.2f", viewModel.totalDistanceMeters / 1000),
                    unit: "km (GPS)"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: -4)
    }

    private func statItem(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(AppColors.primaryBlueDark)
            Text(value)
                .font(.appBold(size: 18))
                .foregroundStyle(AppColors.textPrimary)
            Text(unit)
                .font(.appRegular(size: 11))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var formattedElapsedTime: String {
        let total = Int(viewModel.elapsedTime)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func finishHiking() {
        if let journeyID = viewModel.completeHiking(context: modelContext) {
            router.popToRoot()
            router.navigateTo(.hikingResult(journeyID: journeyID))
        }
    }
}
