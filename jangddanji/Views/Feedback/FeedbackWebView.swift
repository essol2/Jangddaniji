import SafariServices
import SwiftUI

struct FeedbackWebView: UIViewControllerRepresentable {
    private let url = URL(string: "https://forms.gle/bHJhScdEYwkaYfc67")!

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
