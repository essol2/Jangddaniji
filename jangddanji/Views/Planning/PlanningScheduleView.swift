import SwiftUI

struct PlanningScheduleView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppColors.primaryBlueDark)
                    Text("여정 기간")
                        .font(.appBold(size: 18))
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("시작일")
                            .font(.appRegular(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                        DatePicker(
                            "",
                            selection: $viewModel.startDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("종료일")
                            .font(.appRegular(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                        DatePicker(
                            "",
                            selection: $viewModel.endDate,
                            in: viewModel.startDate...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }
                .padding(16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("총 여정 기간")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.numberOfDays)")
                            .font(.appBold(size: 32))
                            .foregroundStyle(AppColors.primaryBlueDark)
                        Text("일")
                            .font(.appBold(size: 18))
                            .foregroundStyle(AppColors.primaryBlueDark)
                    }
                }
                Spacer()
                Image(systemName: "figure.walk")
                    .font(.appRegular(size: 28))
                    .foregroundStyle(AppColors.primaryBlueDark.opacity(0.3))
            }
            .padding(16)
            .background(AppColors.primaryBlue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}
