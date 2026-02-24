import SwiftUI

enum AppColors {
    static let primaryBlue = Color(red: 0.72, green: 0.85, blue: 0.94)
    static let primaryBlueDark = Color(red: 0.55, green: 0.75, blue: 0.90)
    static let accentYellow = Color(red: 0.85, green: 0.92, blue: 0.30)
    static let cardBackground = Color.white
    static let background = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let textPrimary = Color.black
    static let textSecondary = Color.gray
    static let completedGreen = Color.green

    static let entryGradient = LinearGradient(
        colors: [
            Color(red: 0.72, green: 0.85, blue: 0.94),
            Color(red: 0.85, green: 0.92, blue: 0.80),
            Color(red: 0.90, green: 0.95, blue: 0.70)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGradient = LinearGradient(
        colors: [
            Color(red: 0.72, green: 0.85, blue: 0.94),
            Color(red: 0.78, green: 0.88, blue: 0.95)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
