import SwiftUI

enum AppColors {
    // #4CC288 – main green
    static let primaryBlue = Color(red: 0.298, green: 0.761, blue: 0.533)
    // #3A9A6B – deeper green for accents / buttons
    static let primaryBlueDark = Color(red: 0.227, green: 0.604, blue: 0.420)
    // #BFCC5C – muted yellow-green accent
    static let accentYellow = Color(red: 0.749, green: 0.800, blue: 0.361)
    static let cardBackground = Color.white
    static let background = Color(red: 0.96, green: 0.97, blue: 0.96)
    static let textPrimary = Color.black
    static let textSecondary = Color.gray
    static let completedGreen = Color(red: 0.298, green: 0.761, blue: 0.533)

    // #4CC288 → #83A363 → #BFCC5C
    static let entryGradient = LinearGradient(
        colors: [
            Color(red: 0.298, green: 0.761, blue: 0.533),  // #4CC288
            Color(red: 0.514, green: 0.639, blue: 0.388),  // #83A363
            Color(red: 0.749, green: 0.800, blue: 0.361)   // #BFCC5C
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGradient = LinearGradient(
        colors: [
            Color(red: 0.298, green: 0.761, blue: 0.533),  // #4CC288
            Color(red: 0.400, green: 0.700, blue: 0.460)   // mid-tone
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
