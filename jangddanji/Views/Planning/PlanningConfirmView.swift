import SwiftUI

struct PlanningConfirmView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isCalculating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("경로를 계산하고 있습니다...")
                            .font(.appRegular(size: 15))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.appRegular(size: 40))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.appRegular(size: 15))
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("다시 시도") {
                            Task { await viewModel.calculateRoute() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.primaryBlueDark)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if !viewModel.daySegments.isEmpty {
                    // Summary
                    VStack(spacing: 12) {
                        summaryRow(
                            "총 거리",
                            DistanceFormatter.formattedDetailed(viewModel.routeResult?.totalDistance ?? 0)
                        )
                        summaryRow("총 일수", "\(viewModel.numberOfDays)일")
                        summaryRow(
                            "일 평균",
                            DistanceFormatter.formattedDetailed(
                                (viewModel.routeResult?.totalDistance ?? 0) / Double(viewModel.numberOfDays)
                            )
                        )
                    }
                    .padding(16)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                    // Day segments list
                    Text("일자별 계획")
                        .font(.appBold(size: 16))
                        .padding(.top, 8)

                    ForEach(Array(viewModel.daySegments.enumerated()), id: \.offset) { index, segment in
                        let names = index < viewModel.segmentNames.count
                            ? viewModel.segmentNames[index]
                            : (start: "구간 \(index + 1)", end: "")
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Day \(segment.dayNumber)")
                                    .font(.appRegular(size: 12))
                                    .foregroundStyle(AppColors.primaryBlueDark)
                                Text("\(names.start) → \(names.end)")
                                    .font(.appRegular(size: 15))
                            }
                            Spacer()
                            Text(DistanceFormatter.formatted(segment.distance))
                                .font(.appBold(size: 15))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(14)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .task {
            if viewModel.daySegments.isEmpty && !viewModel.isCalculating {
                await viewModel.calculateRoute()
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.appRegular(size: 14))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.appBold(size: 16))
        }
    }
}
