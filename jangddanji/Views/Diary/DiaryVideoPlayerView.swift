import AVKit
import Photos
import SwiftUI

struct DiaryVideoPlayerView: View {
    let videoPath: String

    @Environment(AppRouter.self) private var router
    @State private var player: AVPlayer?
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 닫기
                HStack {
                    Button {
                        router.pop()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("닫기")
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 12)

                // 영상 플레이어
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(9/16, contentMode: .fit)
                        .padding(.horizontal, 16)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }

                Spacer()

                // 다운로드 버튼
                Button {
                    saveToPhotoLibrary()
                } label: {
                    Label("사진 앨범에 저장", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            // 토스트
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            let url = URL(fileURLWithPath: videoPath)
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func saveToPhotoLibrary() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                showToastMessage("사진 접근 권한이 필요합니다.")
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let url = URL(fileURLWithPath: videoPath)
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            } completionHandler: { success, error in
                if success {
                    showToastMessage("저장됐습니다!")
                } else {
                    showToastMessage("저장에 실패했습니다.")
                }
            }
        }
    }

    private func showToastMessage(_ message: String) {
        Task { @MainActor in
            toastMessage = message
            withAnimation { showToast = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showToast = false }
        }
    }
}
