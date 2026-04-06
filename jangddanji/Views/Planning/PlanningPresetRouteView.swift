import SwiftUI

struct PlanningPresetRouteView: View {
    @Bindable var viewModel: PlanningViewModel

    private let presets = PresetRoute.allPresets

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("유명 경로 불러오기")
                    .font(.appBold(size: 18))
                Text("걷고 싶은 경로를 선택하세요")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(presets) { preset in
                        presetCard(preset)
                    }
                }
            }

            // 프리셋 선택 후: 경로 정보 + 분할 방식 선택
            if let gpxResult = viewModel.gpxResult, viewModel.selectedPreset != nil {
                VStack(alignment: .leading, spacing: 16) {
                    // 경로 정보
                    HStack {
                        infoItem("총 거리", DistanceFormatter.formattedDetailed(gpxResult.totalDistance))
                        Spacer()
                        if !gpxResult.courses.isEmpty {
                            infoItem("코스 수", "\(gpxResult.courses.count)코스")
                        }
                    }
                    .padding(14)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                    // 분할 방식 선택
                    if !gpxResult.courses.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("일정 나누기")
                                .font(.appBold(size: 15))
                                .foregroundStyle(AppColors.textPrimary)

                            strategyButton(
                                strategy: .byCourse,
                                icon: "signpost.right.fill",
                                title: "코스별로 걷기",
                                description: "\(gpxResult.courses.count)코스 = \(gpxResult.courses.count)일",
                                isSelected: viewModel.splittingStrategy == .byCourse
                            )

                            strategyButton(
                                strategy: .equalDistance,
                                icon: "ruler.fill",
                                title: "날짜/거리로 나누기",
                                description: "원하는 기간이나 하루 거리로 설정",
                                isSelected: viewModel.splittingStrategy == .equalDistance
                            )
                        }
                    }
                }
            }

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
        .onChange(of: viewModel.gpxResult?.courses.isEmpty) {
            // 코스 정보가 없는 프리셋이면 자동으로 균등 분할 선택
            if let gpxResult = viewModel.gpxResult, gpxResult.courses.isEmpty {
                viewModel.splittingStrategy = .equalDistance
            }
        }
    }

    // MARK: - Components

    private func presetCard(_ preset: PresetRoute) -> some View {
        let isSelected = viewModel.selectedPreset == preset

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.splittingStrategy = nil
                viewModel.loadPresetRoute(preset)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "map.fill")
                    .font(.appRegular(size: 20))
                    .foregroundStyle(isSelected ? .white : AppColors.primaryBlueDark)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected
                            ? AppColors.primaryBlueDark
                            : AppColors.primaryBlueDark.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.appBold(size: 16))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(preset.description)
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Label(preset.region, systemImage: "mappin")
                        Label(preset.estimatedDistance, systemImage: "figure.walk")
                    }
                    .font(.appRegular(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.primaryBlueDark)
                        .font(.appRegular(size: 22))
                }
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? AppColors.primaryBlueDark : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func strategyButton(
        strategy: PlanningViewModel.SplittingStrategy,
        icon: String,
        title: String,
        description: String,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.splittingStrategy = strategy
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.appRegular(size: 18))
                    .foregroundStyle(isSelected ? .white : AppColors.primaryBlueDark)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected
                            ? AppColors.primaryBlueDark
                            : AppColors.primaryBlueDark.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appBold(size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(description)
                        .font(.appRegular(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.primaryBlueDark)
                        .font(.appRegular(size: 20))
                }
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? AppColors.primaryBlueDark : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
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
