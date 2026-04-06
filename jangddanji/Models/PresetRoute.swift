import Foundation

struct PresetRoute: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let region: String
    let estimatedDistance: String
    let gpxFileName: String

    var gpxURL: URL? {
        Bundle.main.url(forResource: gpxFileName, withExtension: "gpx")
    }

    static let allPresets: [PresetRoute] = [
        PresetRoute(
            id: "jeju-olle-full",
            name: "제주올레길 전체코스",
            description: "제주도를 한 바퀴 도는 도보 여행 코스",
            region: "제주특별자치도",
            estimatedDistance: "약 425km",
            gpxFileName: "jeju-olle-full"
        ),
    ]
}
