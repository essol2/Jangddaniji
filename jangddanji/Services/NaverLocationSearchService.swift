import Foundation
import CoreLocation

// MARK: - Naver API Response Models

private struct NaverLocalSearchResponse: Decodable {
    let items: [NaverLocalSearchItem]
}

private struct NaverLocalSearchItem: Decodable {
    let title: String
    let address: String
    let roadAddress: String
    let mapx: String
    let mapy: String

    var cleanTitle: String {
        title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

// MARK: - Naver Search Error

enum NaverSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case missingAPIKeys

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 검색 URL입니다."
        case .invalidResponse: return "검색 응답을 처리할 수 없습니다."
        case .httpError(let code): return "검색 오류 (HTTP \(code))"
        case .missingAPIKeys: return "네이버 API 키가 설정되지 않았습니다."
        }
    }
}

// MARK: - Naver Location Search Service

final class NaverLocationSearchService: LocationSearchServiceProtocol {
    private let clientId: String
    private let clientSecret: String
    private let fallback: LocationSearchServiceProtocol

    init(
        clientId: String = Secrets.naverClientId,
        clientSecret: String = Secrets.naverClientSecret,
        fallback: LocationSearchServiceProtocol = AppleLocationSearchService()
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.fallback = fallback
    }

    func search(query: String) async throws -> [LocationResult] {
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            return try await fallback.search(query: query)
        }

        do {
            return try await naverSearch(query: query)
        } catch {
            return try await fallback.search(query: query)
        }
    }

    private func naverSearch(query: String) async throws -> [LocationResult] {
        var components = URLComponents(string: "https://openapi.naver.com/v1/search/local.json")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "display", value: "5"),
            URLQueryItem(name: "start", value: "1"),
            URLQueryItem(name: "sort", value: "random"),
        ]

        guard let url = components.url else {
            throw NaverSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(clientId, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NaverSearchError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw NaverSearchError.httpError(httpResponse.statusCode)
        }

        let searchResponse = try JSONDecoder().decode(NaverLocalSearchResponse.self, from: data)

        return searchResponse.items.compactMap { item -> LocationResult? in
            guard let mapx = Double(item.mapx),
                  let mapy = Double(item.mapy) else { return nil }

            // Naver API returns WGS84 coordinates as integers (×10,000,000)
            let latitude = mapy / 10_000_000.0
            let longitude = mapx / 10_000_000.0
            let subtitle = item.roadAddress.isEmpty ? item.address : item.roadAddress

            return LocationResult(
                name: item.cleanTitle,
                subtitle: subtitle,
                latitude: latitude,
                longitude: longitude
            )
        }
    }
}
