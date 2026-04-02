import SwiftUI
import UniformTypeIdentifiers

struct PlanningGPXImportView: View {
    @Bindable var viewModel: PlanningViewModel
    @State private var showFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("GPX 파일 가져오기")
                    .font(.appBold(size: 18))
                Text("GPX 파일에서 경로를 불러옵니다")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let gpxResult = viewModel.gpxResult {
                // 파싱 성공 상태
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.appRegular(size: 24))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.gpxFileName ?? "GPX 파일")
                                .font(.appBold(size: 16))
                                .foregroundStyle(AppColors.textPrimary)
                            if let trackName = gpxResult.trackName {
                                Text(trackName)
                                    .font(.appRegular(size: 13))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        Spacer()
                        Button {
                            viewModel.gpxResult = nil
                            viewModel.gpxFileName = nil
                            showFilePicker = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(AppColors.primaryBlueDark)
                                .font(.appRegular(size: 18))
                        }
                    }

                    Divider()

                    HStack {
                        infoItem("총 거리", DistanceFormatter.formattedDetailed(gpxResult.totalDistance))
                        Spacer()
                        infoItem("좌표 수", "\(gpxResult.polylinePoints.count)개")
                    }
                }
                .padding(16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            } else {
                // 파일 선택 전
                Button { showFilePicker = true } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.appRegular(size: 40))
                            .foregroundStyle(AppColors.primaryBlueDark)
                        Text("GPX 파일을 선택하세요")
                            .font(.appBold(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("파일 앱에서 .gpx 파일을 선택합니다")
                            .font(.appRegular(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                AppColors.primaryBlueDark.opacity(0.3),
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            // 에러 메시지
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.appRegular(size: 14))
                        .foregroundStyle(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "gpx") ?? .xml
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importGPX(from: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func infoItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appRegular(size: 12))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.appBold(size: 16))
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}
