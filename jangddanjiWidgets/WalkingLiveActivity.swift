import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget Colors (위젯에서 사용할 앱 테마 컬러)
private enum WidgetColors {
    static let primaryGreen = Color(red: 0.298, green: 0.761, blue: 0.533)   // #4CC288
    static let darkGreen = Color(red: 0.227, green: 0.604, blue: 0.420)      // #3A9A6B
    static let accentYellow = Color(red: 0.749, green: 0.800, blue: 0.361)   // #BFCC5C
}

// MARK: - Live Activity Configuration

struct WalkingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkingActivityAttributes.self) { context in
            // 잠금화면 뷰
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Day \(context.attributes.dayNumber)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(WidgetColors.primaryGreen)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetColors.primaryGreen)
            } minimal: {
                // 원형 진행률
                ZStack {
                    Circle()
                        .stroke(WidgetColors.primaryGreen.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(WidgetColors.primaryGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "figure.walk")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(WidgetColors.primaryGreen)
                }
            }
        }
    }

    // MARK: - Dynamic Island Expanded Views

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Day \(context.attributes.dayNumber)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(WidgetColors.primaryGreen)
            Text(context.attributes.startLocationName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if context.state.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            } else {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(WidgetColors.primaryGreen)
            }
            Text(context.attributes.endLocationName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<WalkingActivityAttributes>) -> some View {
        let state = context.state
        let attrs = context.attributes

        if state.isCompleted {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("구간 완료!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
            }
        } else {
            VStack(spacing: 8) {
                // 걸음수 + 이동거리
                HStack(spacing: 16) {
                    Label {
                        Text("\(state.todaySteps.formatted())걸음")
                            .font(.system(size: 12, weight: .medium))
                    } icon: {
                        Image(systemName: "shoeprints.fill")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.primary)

                    Label {
                        Text(String(format: "%.1fkm", state.todayDistanceKm))
                            .font(.system(size: 12, weight: .medium))
                    } icon: {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.primary)

                    Spacer()

                    let remainingKm = max((attrs.totalDistanceMeters / 1000.0) - state.todayDistanceKm, 0)
                    Text(String(format: "남은 %.1fkm", remainingKm))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(WidgetColors.primaryGreen.opacity(0.2))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(WidgetColors.primaryGreen)
                            .frame(width: max(geo.size.width * state.progress, 0))
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<WalkingActivityAttributes>

    var body: some View {
        let state = context.state
        let attrs = context.attributes

        VStack(spacing: 12) {
            // 헤더: Day N · 여정 제목
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Day \(attrs.dayNumber)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(WidgetColors.primaryGreen)

                Text("·")
                    .foregroundStyle(.secondary)

                Text(attrs.journeyTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if state.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                }
            }

            if state.isCompleted {
                // 완료 상태
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                    Text("구간 완료!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                    Spacer()
                }
            } else {
                // 출발지 → 도착지
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(WidgetColors.darkGreen)
                        Text(attrs.startLocationName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)

                    // 점선 + 아이콘
                    HStack(spacing: 4) {
                        dottedLine
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(WidgetColors.darkGreen)
                        dottedLine
                    }
                    .frame(width: 70)

                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(WidgetColors.darkGreen)
                        Text(attrs.endLocationName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }

                // 걸음수 + 이동거리
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "shoeprints.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(WidgetColors.darkGreen)
                        Text("\(state.todaySteps.formatted())걸음")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WidgetColors.primaryGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10))
                            .foregroundStyle(WidgetColors.darkGreen)
                        Text(String(format: "%.1fkm", state.todayDistanceKm))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WidgetColors.accentYellow.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Spacer()
                }

                // Progress bar + 남은 거리
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(WidgetColors.primaryGreen.opacity(0.15))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(WidgetColors.darkGreen)
                                .frame(width: max(geo.size.width * state.progress, 0))
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text(String(format: "%.1fkm", state.todayDistanceKm))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetColors.darkGreen)

                        Spacer()

                        let totalKm = attrs.totalDistanceMeters / 1000.0
                        let remainingKm = max(totalKm - state.todayDistanceKm, 0)
                        Text(String(format: "남은 %.1fkm", remainingKm))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Text(String(format: "/ %.1fkm", totalKm))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(.systemBackground))
    }

    private var dottedLine: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(WidgetColors.darkGreen.opacity(0.3))
                    .frame(width: 2, height: 2)
            }
        }
    }
}
