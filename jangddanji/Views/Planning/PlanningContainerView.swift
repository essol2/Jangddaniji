import SwiftUI

struct PlanningContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var viewModel = PlanningViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    router.pop()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.appRegular(size: 13))
                        Text("돌아가기")
                            .font(.appRegular(size: 14))
                    }
                    .foregroundStyle(AppColors.primaryBlueDark)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("새로운 여정 계획")
                        .font(.appBold(size: 22))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("나만의 대장정을 설계해보세요")
                        .font(.appRegular(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)

            // Step indicator
            HStack(spacing: 6) {
                let steps = viewModel.activeSteps
                let currentIndex = steps.firstIndex(of: viewModel.currentStep) ?? 0
                ForEach(Array(steps.enumerated()), id: \.element) { index, _ in
                    Capsule()
                        .fill(index <= currentIndex
                              ? AppColors.primaryBlueDark
                              : AppColors.primaryBlue.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .animation(.easeInOut(duration: 0.25), value: viewModel.activeSteps.count)

            // Content
            Group {
                switch viewModel.currentStep {
                case .startLocation:
                    PlanningStartLocationView(viewModel: viewModel)
                case .endLocation:
                    PlanningEndLocationView(viewModel: viewModel)
                case .modeSelection:
                    PlanningModeSelectionView(viewModel: viewModel)
                case .schedule:
                    PlanningScheduleView(viewModel: viewModel)
                case .distance:
                    PlanningDistanceView(viewModel: viewModel)
                case .confirm:
                    PlanningConfirmView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)

            // Bottom buttons
            HStack(spacing: 12) {
                if viewModel.currentStep != .startLocation {
                    Button {
                        viewModel.goBack()
                    } label: {
                        Text("이전")
                            .font(.appBold(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    }
                }

                if viewModel.currentStep == .confirm {
                    Button {
                        startJourney()
                    } label: {
                        Text(viewModel.isCalculating ? "경로 계산 중..." : "여정 시작하기")
                            .font(.appBold(size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(viewModel.isCalculating || viewModel.daySegments.isEmpty
                                        ? AppColors.primaryBlue.opacity(0.5)
                                        : AppColors.primaryBlueDark)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(viewModel.isCalculating || viewModel.daySegments.isEmpty)
                } else {
                    Button {
                        viewModel.goNext()
                    } label: {
                        Text("다음")
                            .font(.appBold(size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(viewModel.canGoNext
                                        ? AppColors.primaryBlueDark
                                        : AppColors.primaryBlue.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!viewModel.canGoNext)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
    }

    private func startJourney() {
        _ = viewModel.createJourney(in: modelContext)
        router.popToRoot()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            router.navigateTo(.dashboard)
        }
    }
}
