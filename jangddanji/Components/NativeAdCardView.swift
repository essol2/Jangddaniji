import SwiftUI
import GoogleMobileAds

// MARK: - SwiftUI Card Wrapper

struct NativeAdCardView: View {
    let nativeAd: GADNativeAd

    var body: some View {
        NativeAdRepresentable(nativeAd: nativeAd)
            .frame(minHeight: 290)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - UIViewRepresentable

private struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: GADNativeAd

    func makeUIView(context: Context) -> GADNativeAdView {
        let adView = GADNativeAdView()
        adView.backgroundColor = .white
        adView.layer.cornerRadius = 16
        adView.clipsToBounds = true

        // AD badge
        let adBadge = PaddedLabel()
        adBadge.text = "AD"
        adBadge.font = UIFont(name: "HakgyoansimBadasseugiTTF-B", size: 10) ?? .boldSystemFont(ofSize: 10)
        adBadge.textColor = .white
        adBadge.backgroundColor = UIColor(red: 0.227, green: 0.604, blue: 0.420, alpha: 0.7)
        adBadge.layer.cornerRadius = 8
        adBadge.clipsToBounds = true
        adBadge.textAlignment = .center
        adBadge.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adBadge)

        // Icon
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 8
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconView)
        adView.iconView = iconView

        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = UIFont(name: "HakgyoansimBadasseugiTTF-B", size: 15) ?? .boldSystemFont(ofSize: 15)
        headlineLabel.textColor = .black
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel

        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = UIFont(name: "HakgyoansimBadasseugiTTF-L", size: 13) ?? .systemFont(ofSize: 13)
        bodyLabel.textColor = .gray
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel

        // Media
        let mediaView = GADMediaView()
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 10
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(mediaView)
        adView.mediaView = mediaView

        // Layout
        NSLayoutConstraint.activate([
            // AD badge
            adBadge.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            adBadge.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            adBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            adBadge.heightAnchor.constraint(equalToConstant: 16),

            // Icon
            iconView.topAnchor.constraint(equalTo: adBadge.bottomAnchor, constant: 10),
            iconView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            // Headline
            headlineLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor, constant: -8),
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            headlineLabel.trailingAnchor.constraint(lessThanOrEqualTo: adView.trailingAnchor, constant: -16),

            // Body
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 2),
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),

            // Media
            mediaView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            mediaView.heightAnchor.constraint(equalToConstant: 200),
            mediaView.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
        ])

        return adView
    }

    func updateUIView(_ adView: GADNativeAdView, context: Context) {
        adView.nativeAd = nativeAd

        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.mediaView?.mediaContent = nativeAd.mediaContent

        // rootViewController for click handling
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
           let rootVC = windowScene.windows.first?.rootViewController {
            nativeAd.rootViewController = rootVC
        }
    }
}

// MARK: - Padded Label for AD badge

private class PaddedLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 12, height: size.height + 4)
    }
}
