import Foundation
import Combine
import GoogleMobileAds

final class InterstitialAdManager: NSObject, ObservableObject {
    static let shared = InterstitialAdManager()

    private var interstitialAd: GADInterstitialAd?
    private let adUnitID: String
    private var showCounter = 0
    private var dismissCompletion: (() -> Void)?

    private init(adUnitID: String = "ca-app-pub-4144682979193082/5679905610") {
        self.adUnitID = adUnitID
        super.init()
    }

    func loadAd() {
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("[AdMob] 전면 광고 로드 실패: \(error.localizedDescription)")
                return
            }
            print("[AdMob] 전면 광고 로드 성공")
            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
        }
    }

    /// 전면 광고를 표시
    func tryShowAd(completion: @escaping () -> Void) {
        guard let ad = interstitialAd else {
            completion()
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            completion()
            return
        }

        dismissCompletion = completion
        ad.present(fromRootViewController: rootVC)
    }
}

extension InterstitialAdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        interstitialAd = nil
        loadAd()
        dismissCompletion?()
        dismissCompletion = nil
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMob] 전면 광고 표시 실패: \(error.localizedDescription)")
        interstitialAd = nil
        loadAd()
        dismissCompletion?()
        dismissCompletion = nil
    }
}
