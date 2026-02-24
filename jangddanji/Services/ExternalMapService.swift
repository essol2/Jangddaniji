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
        toName: String
    ) {
        switch app {
        case .apple:
            let source = MKMapItem(placemark: MKPlacemark(coordinate: from))
            source.name = fromName
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            destination.name = toName
            MKMapItem.openMaps(
                with: [source, destination],
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
            )
        case .naver:
            let fromEncoded = fromName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fromName
            let toEncoded = toName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? toName
            let urlString = "nmap://route/walk?slat=\(from.latitude)&slng=\(from.longitude)&sname=\(fromEncoded)&dlat=\(to.latitude)&dlng=\(to.longitude)&dname=\(toEncoded)&appname=com.sground.jangddanji"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        case .kakao:
            let urlString = "kakaomap://route?sp=\(from.latitude),\(from.longitude)&ep=\(to.latitude),\(to.longitude)&by=FOOT"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        case .google:
            let urlString = "comgooglemaps://?saddr=\(from.latitude),\(from.longitude)&daddr=\(to.latitude),\(to.longitude)&directionsmode=walking"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
