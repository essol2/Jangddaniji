import Foundation
import CoreLocation

enum GPXParseError: LocalizedError {
    case fileReadFailed
    case noTrackPointsFound
    case invalidCoordinates
    case insufficientPoints

    var errorDescription: String? {
        switch self {
        case .fileReadFailed: return "GPX 파일을 읽을 수 없습니다."
        case .noTrackPointsFound: return "GPX 파일에 경로 데이터가 없습니다."
        case .invalidCoordinates: return "유효하지 않은 좌표가 포함되어 있습니다."
        case .insufficientPoints: return "경로에 최소 2개 이상의 지점이 필요합니다."
        }
    }
}

struct GPXCourse {
    let courseName: String
    let points: [CLLocationCoordinate2D]
    let distance: Double
}

struct GPXParseResult {
    let polylinePoints: [CLLocationCoordinate2D]
    let totalDistance: Double
    let trackName: String?
    let courses: [GPXCourse]
}

final class GPXParserService: NSObject, XMLParserDelegate {

    private var coordinates: [CLLocationCoordinate2D] = []
    private var trackName: String?
    private var currentElement = ""
    private var currentText = ""
    private var isInsideTrackOrRoute = false

    // 코스별 파싱
    private var isInsideSegment = false
    private var currentSegmentPoints: [CLLocationCoordinate2D] = []
    private var currentSegmentName: String?
    private var parsedCourses: [GPXCourse] = []
    private var segmentNameParsed = false

    func parseGPX(from url: URL) throws -> GPXParseResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw GPXParseError.fileReadFailed
        }

        // Reset state
        coordinates = []
        trackName = nil
        currentElement = ""
        currentText = ""
        isInsideTrackOrRoute = false
        isInsideSegment = false
        currentSegmentPoints = []
        currentSegmentName = nil
        parsedCourses = []
        segmentNameParsed = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        guard !coordinates.isEmpty else {
            throw GPXParseError.noTrackPointsFound
        }

        guard coordinates.count >= 2 else {
            throw GPXParseError.insufficientPoints
        }

        let totalDistance = calculateTotalDistance(coordinates)

        return GPXParseResult(
            polylinePoints: coordinates,
            totalDistance: totalDistance,
            trackName: trackName,
            courses: parsedCourses
        )
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        currentElement = elementName

        if elementName == "trk" || elementName == "rte" {
            isInsideTrackOrRoute = true
        }

        if elementName == "trkseg" || elementName == "rteseg" {
            isInsideSegment = true
            currentSegmentPoints = []
            currentSegmentName = nil
            segmentNameParsed = false
        }

        if elementName == "trkpt" || elementName == "rtept" {
            guard let latStr = attributeDict["lat"],
                  let lonStr = attributeDict["lon"],
                  let lat = Double(latStr),
                  let lon = Double(lonStr),
                  (-90...90).contains(lat),
                  (-180...180).contains(lon) else {
                return
            }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            coordinates.append(coord)
            if isInsideSegment {
                currentSegmentPoints.append(coord)
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "name" {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "name" {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if isInsideSegment && !segmentNameParsed {
                    currentSegmentName = trimmed
                    segmentNameParsed = true
                } else if isInsideTrackOrRoute && trackName == nil {
                    trackName = trimmed
                }
            }
        }

        if elementName == "trkseg" || elementName == "rteseg" {
            if currentSegmentPoints.count >= 2 {
                let distance = calculateTotalDistance(currentSegmentPoints)
                let course = GPXCourse(
                    courseName: currentSegmentName ?? "\(parsedCourses.count + 1)코스",
                    points: currentSegmentPoints,
                    distance: distance
                )
                parsedCourses.append(course)
            }
            isInsideSegment = false
        }

        if elementName == "trk" || elementName == "rte" {
            isInsideTrackOrRoute = false
        }

        currentText = ""
        currentElement = ""
    }

    // MARK: - Distance Calculation

    private func calculateTotalDistance(_ points: [CLLocationCoordinate2D]) -> Double {
        var total: Double = 0
        for i in 1..<points.count {
            total += haversineDistance(from: points[i - 1], to: points[i])
        }
        return total
    }

    private func haversineDistance(
        from c1: CLLocationCoordinate2D,
        to c2: CLLocationCoordinate2D
    ) -> Double {
        let R = 6_371_000.0 // Earth radius in meters
        let dLat = (c2.latitude - c1.latitude) * .pi / 180
        let dLon = (c2.longitude - c1.longitude) * .pi / 180
        let lat1 = c1.latitude * .pi / 180
        let lat2 = c2.latitude * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
