import Foundation

enum Secrets {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
            print("❌ [Secrets] Secrets.plist 파일을 찾을 수 없음 (Bundle에 포함되었는지 확인)")
            return [:]
        }
        guard let data = try? Data(contentsOf: url) else {
            print("❌ [Secrets] Secrets.plist 파일 읽기 실패")
            return [:]
        }
        guard let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            print("❌ [Secrets] Secrets.plist 파싱 실패")
            return [:]
        }
        print("✅ [Secrets] Secrets.plist 로드 성공 - 키 목록: \(dict.keys.sorted())")
        return dict
    }()

    static var naverClientId: String {
        secrets["NAVER_CLIENT_ID"] as? String ?? ""
    }

    static var naverClientSecret: String {
        secrets["NAVER_CLIENT_SECRET"] as? String ?? ""
    }
}
