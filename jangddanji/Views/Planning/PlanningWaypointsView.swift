import SwiftUI

struct PlanningWaypointsView: View {
    @Bindable var viewModel: PlanningViewModel
    @State private var newWaypoint: LocationResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("경유지 추가")
                        .font(.appBold(size: 18))
                    Text("경유하고 싶은 지점을 추가하세요 (선택사항)")
                        .font(.appRegular(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                }

                // 경로 요약
                routeSummarySection

                // 경유지 추가
                if viewModel.waypoints.count < 5 {
                    LocationSearchBar(
                        placeholder: "경유지를 검색하세요",
                        selectedLocation: $newWaypoint
                    )
                    .onChange(of: newWaypoint) { _, location in
                        if let location {
                            viewModel.waypoints.append(location)
                            newWaypoint = nil
                        }
                    }
                } else {
                    Text("경유지는 최대 5개까지 추가할 수 있습니다")
                        .font(.appRegular(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, 8)
                }

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
                subtitle: "출발지",
                isRemovable: false
            )

            // 경유지들
            ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, wp in
                connectorLine
                routePointRow(
                    icon: "\(index + 1).circle.fill",
                    color: .orange,
                    name: wp.name,
                    subtitle: "경유지 \(index + 1)",
                    isRemovable: true,
                    onRemove: { viewModel.waypoints.remove(at: index) }
                )
            }

            connectorLine

            // 목적지
            routePointRow(
                icon: "flag.checkered",
                color: .red,
                name: viewModel.endLocation?.name ?? "",
                subtitle: "목적지",
                isRemovable: false
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
        subtitle: String,
        isRemovable: Bool,
        onRemove: (() -> Void)? = nil
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

            if isRemovable {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onRemove?()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                        .font(.appRegular(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
