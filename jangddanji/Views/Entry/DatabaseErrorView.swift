import SwiftUI

struct DatabaseErrorView: View {
    let errorMessage: String

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("데이터베이스 오류")
                    .font(.appBold(size: 22))
                    .foregroundStyle(AppColors.textPrimary)

                Text("데이터에 문제가 발생했습니다.\n앱을 종료 후 다시 시도해주세요.\n문제가 지속되면 앱을 재설치해주세요.")
                    .font(.appRegular(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text(errorMessage)
                    .font(.appRegular(size: 12))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                    .padding(.horizontal, 20)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
    }
}
