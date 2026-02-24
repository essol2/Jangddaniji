import SwiftUI

struct DayRouteRowView: View {
    let dayRoute: DayRoute

    private var isToday: Bool { Calendar.current.isDateInToday(dayRoute.date) }
    private var isCompleted: Bool { dayRoute.status == .completed }

    @State private var gradientPhase: CGFloat = -0.3

    var body: some View {
        HStack(spacing: 12) {
            // Day badge
            VStack(spacing: 2) {
                Text("Day")
                    .font(.appRegular(size: 10))
                    .foregroundStyle(isToday ? .white.opacity(0.8) : AppColors.textSecondary)
                Text("\(dayRoute.dayNumber)")
                    .font(.appBold(size: 18))
                    .foregroundStyle(isToday ? .white : AppColors.textPrimary)
            }
            .frame(width: 44)

            // Route info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if isToday {
                        Text("오늘")
                            .font(.appBold(size: 11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.25))
                            .clipShape(Capsule())
                    }
                    Text(AppDateFormatter.dayMonth.string(from: dayRoute.date))
                        .font(.appRegular(size: 12))
                        .foregroundStyle(isToday ? .white.opacity(0.8) : AppColors.textSecondary)
                }

                HStack(spacing: 4) {
                    Text(dayRoute.startLocationName)
                        .font(.appRegular(size: 14))
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.appRegular(size: 10))
                        .foregroundStyle(isToday ? .white.opacity(0.6) : AppColors.textSecondary)
                    Text(dayRoute.endLocationName)
                        .font(.appRegular(size: 14))
                        .lineLimit(1)
                }
                .foregroundStyle(isToday ? .white : AppColors.textPrimary)
            }

            Spacer()

            // Distance + status
            VStack(alignment: .trailing, spacing: 4) {
                Text(DistanceFormatter.formattedDetailed(dayRoute.distance))
                    .font(.appBold(size: 13))
                    .foregroundStyle(isToday ? .white : AppColors.textPrimary)

                statusIcon
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            if isToday {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.227, green: 0.604, blue: 0.420), location: 0.0 + gradientPhase),   // #3A9A6B deep green
                        .init(color: Color(red: 0.298, green: 0.761, blue: 0.533), location: 0.25 + gradientPhase),  // #4CC288 main green
                        .init(color: Color(red: 0.427, green: 0.835, blue: 0.627), location: 0.5 + gradientPhase),   // #6DD5A0 light mint
                        .init(color: Color(red: 0.298, green: 0.761, blue: 0.533), location: 0.75 + gradientPhase),  // #4CC288 main green
                        .init(color: Color(red: 0.227, green: 0.604, blue: 0.420), location: 1.0 + gradientPhase)    // #3A9A6B deep green
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 3.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        gradientPhase = 0.3
                    }
                }
            } else {
                AppColors.cardBackground
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: isToday ? AppColors.primaryBlueDark.opacity(0.3) : .black.opacity(0.04), radius: 4, y: 2)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch dayRoute.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.appRegular(size: 18))
                .foregroundStyle(isToday ? .white : AppColors.completedGreen)
        case .today:
            Image(systemName: "figure.walk.circle.fill")
                .font(.appRegular(size: 18))
                .foregroundStyle(.white)
        case .skipped:
            Image(systemName: "minus.circle.fill")
                .font(.appRegular(size: 18))
                .foregroundStyle(.orange)
        case .upcoming:
            Image(systemName: "circle")
                .font(.appRegular(size: 18))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
        }
    }
}
