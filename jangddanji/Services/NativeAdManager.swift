import Foundation
import Combine
import GoogleMobileAds

final class NativeAdManager: NSObject, ObservableObject {
    @Published private(set) var nativeAd: GADNativeAd?
    @Published private(set) var isLoading = false

    private var adLoader: GADAdLoader?
    private let adUnitID: String
    private var retryCount = 0
    private let maxRetries = 3

    init(adUnitID: String = "ca-app-pub-4144682979193082/4524578958") {
        self.adUnitID = adUnitID
        super.init()
    }

    func loadAd() {
        guard !isLoading else { return }
        isLoading = true

        let adLoader = GADAdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        adLoader.delegate = self
        self.adLoader = adLoader
        adLoader.load(GADRequest())
    }

    private func scheduleRetry() {
        guard retryCount < maxRetries else { return }
        retryCount += 1
        let delay = 30.0 * Double(retryCount)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadAd()
        }
    }
}

extension NativeAdManager: GADNativeAdLoaderDelegate {
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        print("[AdMob] 네이티브 광고 로드 성공")
        self.nativeAd = nativeAd
        self.isLoading = false
        self.retryCount = 0
    }

    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        print("[AdMob] 광고 로드 실패: \(error.localizedDescription)")
        self.isLoading = false
        scheduleRetry()
    }
}
