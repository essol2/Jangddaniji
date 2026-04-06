import SwiftUI

struct PlanningWaypointsView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("경로 확인")
                        .font(.appBold(size: 18))
                    Text("최종적으로 이 경로가 맞나요?")
                        .font(.appRegular(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                }

                // 경로 요약
                routeSummarySection

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    private var routeSummarySection: some View {
        VStack(spacing: 0) {
            // 출발지
            routePointRow(
                icon: "flag.fill",
                color: AppColors.primaryBlueDark,
                name: viewModel.startLocation?.name ?? "",
                subtitle: "출발지"
            )

            // 경유지들
            ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, wp in
                connectorLine
                routePointRow(
                    icon: "\(index + 1).circle.fill",
                    color: .orange,
                    name: wp.name,
                    subtitle: "경유지 \(index + 1)"
                )
            }

            connectorLine

            // 목적지
            routePointRow(
                icon: "flag.checkered",
                color: .red,
                name: viewModel.endLocation?.name ?? "",
                subtitle: "목적지"
            )
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var connectorLine: some View {
        HStack {
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(width: 2, height: 20)
                .padding(.leading, 15)
            Spacer()
        }
    }

    private func routePointRow(
        icon: String,
        color: Color,
        name: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.appRegular(size: 16))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.appBold(size: 14))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.appRegular(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
    }
}
