import SwiftUI

struct PlanningRouteSourceView: View {
    @Bindable var viewModel: PlanningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("경로를 어떻게 입력할까요?")
                    .font(.appBold(size: 18))
                Text("경로 입력 방식을 선택하세요")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }

            sourceCard(
                source: .manual,
                icon: "pencil.and.list.clipboard",
                title: "직접 입력하기",
                description: "출발지와 목적지를 검색해서\n경로를 직접 설정합니다",
                isSelected: viewModel.routeSource == .manual
            )

            sourceCard(
                source: .gpxImport,
                icon: "doc.badge.arrow.up",
                title: "GPX 파일 가져오기",
                description: "미리 만들어둔 GPX 파일로\n경로를 불러옵니다",
                isSelected: viewModel.routeSource == .gpxImport
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func sourceCard(
        source: PlanningViewModel.RouteSource,
        icon: String,
        title: String,
        description: String,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.routeSource = source
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
