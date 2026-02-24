import SwiftUI

struct PlanningStartLocationView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("출발지")
                .font(.appRegular(size: 14))
                .foregroundStyle(AppColors.textSecondary)

            LocationSearchBar(
                placeholder: "출발 지역을 입력하세요",
                selectedLocation: $viewModel.startLocation
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}
