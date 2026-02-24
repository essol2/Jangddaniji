import SwiftUI
import SwiftData

struct EntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Journey> { $0.statusRawValue == "active" })
    private var activeJourneys: [Journey]
    @Query(filter: #Predicate<Journey> { $0.statusRawValue == "completed" })
    private var completedJourneys: [Journey]

    @State private var hasCheckedState = false

    var body: some View {
        ZStack {
            AppColors.entryGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo icon
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.9))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 36))
                            .foregroundStyle(AppColors.primaryBlueDark)
                    }
                    .padding(.bottom, 20)

                // App name
                Text("장딴지")
                    .font(.jejuDoldam(size: 36))
                    .foregroundStyle(AppColors.textPrimary)

                // Tagline
                Text("당신의 장거리 단짝 지도")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 4)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        router.navigateTo(.planning)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 18))
                            Text("새로운 발걸음")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.primaryBlueDark)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if !completedJourneys.isEmpty {
                        Button {
                            router.navigateTo(.archiveList)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 18))
                                Text("발걸음 기록보기")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 40)

                // Bottom text
                VStack(spacing: 2) {
                    Text("한 걸음 한 걸음이 모여")
                    Text("위대한 여정을 만듭니다")
                }
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            guard !hasCheckedState else { return }
            hasCheckedState = true
            if !activeJourneys.isEmpty {
                DispatchQueue.main.async {
                    router.navigateTo(.dashboard)
                }
            }
        }
    }
}
