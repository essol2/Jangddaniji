import Foundation
import UIKit
import MapKit

enum MapApp: String, CaseIterable, Identifiable {
    case apple = "Apple Maps"
    case naver = "네이버 지도"
    case kakao = "카카오맵"
    case google = "Google Maps"

    var id: String { rawValue }

    var urlScheme: String {
        switch self {
        case .apple: return ""
        case .naver: return "nmap://"
        case .kakao: return "kakaomap://"
        case .google: return "comgooglemaps://"
        }
    }

    var iconName: String {
        switch self {
        case .apple: return "map.fill"
        case .naver: return "n.circle.fill"
        case .kakao: return "k.circle.fill"
        case .google: return "g.circle.fill"
        }
    }
}

final class ExternalMapService {
    func availableApps() -> [MapApp] {
        MapApp.allCases.filter { app in
            if app == .apple { return true }
            guard let url = URL(string: app.urlScheme) else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    @available(iOS, deprecated: 26.0)
    func openDirections(
        app: MapApp,
        from: CLLocationCoordinate2D,
        fromName: String,
        to: CLLocationCoordinate2D,
        toName: String,
        waypoints: [WaypointCoordinate] = []
    ) {
        switch app {
        case .apple:
            var items: [MKMapItem] = []
            let source = MKMapItem(placemark: MKPlacemark(coordinate: from))
            source.name = fromName
            items.append(source)

            for wp in waypoints {
                let item = MKMapItem(placemark: MKPlacemark(
                    coordinate: CLLocationCoordinate2D(latitude: wp.latitude, longitude: wp.longitude)
                ))
                item.name = wp.name
                items.append(item)
            }

            let destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            destination.name = toName
            items.append(destination)

            MKMapItem.openMaps(
                with: items,
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
            )

        case .naver:
            let fromEncoded = fromName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fromName
            let toEncoded = toName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? toName
            var urlString = "nmap://route/walk?slat=\(from.latitude)&slng=\(from.longitude)&sname=\(fromEncoded)&dlat=\(to.latitude)&dlng=\(to.longitude)&dname=\(toEncoded)"

            // 경유지 추가 (v1, v2, v3...)
            for (index, wp) in waypoints.prefix(5).enumerated() {
                let num = index + 1
                let nameEncoded = wp.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? wp.name
                urlString += "&v\(num)lat=\(wp.latitude)&v\(num)lng=\(wp.longitude)&v\(num)name=\(nameEncoded)"
            }

            urlString += "&appname=com.sground.jangddanji"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }

        case .kakao:
            var urlString = "kakaomap://route?sp=\(from.latitude),\(from.longitude)&ep=\(to.latitude),\(to.longitude)"

            // 경유지 추가 (vp, vp2, vp3, vp4, vp5)
            for (index, wp) in waypoints.prefix(5).enumerated() {
                let key = index == 0 ? "vp" : "vp\(index + 1)"
                urlString += "&\(key)=\(wp.latitude),\(wp.longitude)"
            }

            urlString += "&by=FOOT"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }

        case .google:
            var urlString = "comgooglemaps://?saddr=\(from.latitude),\(from.longitude)&daddr=\(to.latitude),\(to.longitude)&directionsmode=walking"

            // 경유지 추가 (waypoints 파라미터, | 로 구분)
            if !waypoints.isEmpty {
                let waypointStr = waypoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
                if let encoded = waypointStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    urlString += "&waypoints=\(encoded)"
                }
            }

            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
