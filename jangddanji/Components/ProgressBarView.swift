import SwiftUI

struct ProgressBarView: View {
    let progress: Double // 0.0 ~ 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.primaryBlueDark)
                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: 10)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 10)
    }
}
