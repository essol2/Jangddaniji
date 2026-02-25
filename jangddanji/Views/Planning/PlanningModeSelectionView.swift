import SwiftUI

struct PlanningModeSelectionView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("어떻게 계획할까요?")
                    .font(.appBold(size: 18))
                Text("여정 계획 방식을 선택하세요")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Mode A: 여정 기간으로 계획
            modeCard(
                mode: .byDuration,
                icon: "calendar",
                title: "여정 기간으로 계획하기",
                description: "시작일과 종료일을 정하면\n기간에 맞춰 경로를 나눠드려요",
                isSelected: viewModel.planningMode == .byDuration
            )

            // Mode B: 하루 목표 거리로 계획
            modeCard(
                mode: .byDistance,
                icon: "figure.walk",
                title: "하루 목표 거리로 계획하기",
                description: "하루에 걸을 거리를 정하면\n총 일수를 자동으로 계산해드려요",
                isSelected: viewModel.planningMode == .byDistance
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func modeCard(
        mode: PlanningViewModel.PlanningMode,
        icon: String,
        title: String,
        description: String,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.planningMode = mode
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.appRegular(size: 24))
                    .foregroundStyle(isSelected ? .white : AppColors.primaryBlueDark)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected
                            ? AppColors.primaryBlueDark
                            : AppColors.primaryBlueDark.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appBold(size: 16))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(description)
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.primaryBlueDark)
                        .font(.appRegular(size: 22))
                }
            }
            .padding(16)
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
}
