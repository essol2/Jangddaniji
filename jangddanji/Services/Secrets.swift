import Foundation

enum Secrets {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return [:]
        }
        return dict
    }()

    static var naverClientId: String {
        secrets["NAVER_CLIENT_ID"] as? String ?? ""
    }

    static var naverClientSecret: String {
        secrets["NAVER_CLIENT_SECRET"] as? String ?? ""
    }
}
