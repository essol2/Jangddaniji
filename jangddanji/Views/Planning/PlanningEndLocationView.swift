import SwiftUI

struct PlanningEndLocationView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("목적지")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            LocationSearchBar(
                placeholder: "목적지를 입력하세요",
                selectedLocation: $viewModel.endLocation
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}
