import SwiftUI

struct PlanningDistanceView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("하루에 몇 km씩 걸을까요?")
                    .font(.appBold(size: 18))
                Text("자신의 체력에 맞는 목표를 설정하세요")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: 20) {
                HStack {
                    Text("일일 목표 거리")
                        .font(.appRegular(size: 15))

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(Int(viewModel.dailyDistanceKm))")
                            .font(.appBold(size: 20))
                            .foregroundStyle(AppColors.primaryBlueDark)
                            .frame(minWidth: 36)
                        Text("km")
                            .font(.appRegular(size: 15))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(spacing: 4) {
                    Slider(value: $viewModel.dailyDistanceKm, in: 5...50, step: 1)
                        .tint(AppColors.primaryBlueDark)

                    HStack {
                        Text("5km")
                        Spacer()
                        Text("50km")
                    }
                    .font(.appRegular(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                }

                // Recommendation
                if viewModel.dailyDistanceKm <= 15 {
                    recommendationBadge("가벼운 산책 코스", color: .green)
                } else if viewModel.dailyDistanceKm <= 25 {
                    recommendationBadge("적당한 거리", color: AppColors.primaryBlueDark)
                } else if viewModel.dailyDistanceKm <= 35 {
                    recommendationBadge("도전적인 코스", color: .orange)
                } else {
                    recommendationBadge("상당히 힘든 코스", color: .red)
                }
            }
            .padding(20)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            // 출발 예정일 (Mode B용)
            HStack {
                Text("출발 예정일")
                    .font(.appBold(size: 15))

                Spacer()

                DatePicker(
                    "",
                    selection: $viewModel.startDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ko_KR"))
            }
            .padding(20)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func recommendationBadge(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.appRegular(size: 13))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
