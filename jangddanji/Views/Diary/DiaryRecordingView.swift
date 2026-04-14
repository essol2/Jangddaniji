import AVFoundation
import SwiftData
import SwiftUI

struct DiaryRecordingView: View {
    let dayRouteID: UUID
    let hour: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var dayRoutes: [DayRoute]

    init(dayRouteID: UUID, hour: Int) {
        self.dayRouteID = dayRouteID
        self.hour = hour
        _dayRoutes = Query(filter: #Predicate<DayRoute> { $0.id == dayRouteID })
    }

    var body: some View {
        if let dayRoute = dayRoutes.first {
            DiaryRecordingContentView(dayRoute: dayRoute, hour: hour)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
        }
    }
}

private struct DiaryRecordingContentView: View {
    let dayRoute: DayRoute
    let hour: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var recordingService = DiaryRecordingService()
    @State private var isRecording = false
    @State private var remainingTime: Double = 2.0
    @State private var showToast = false
    @State private var errorMessage: String?
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 카메라 프리뷰
            CameraPreviewView(session: recordingService.captureSession)
                .ignoresSafeArea()

            // 상단 오버레이
            VStack {
                HStack {
                    Button {
                        router.pop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(String(format: "%02d:00 촬영", hour))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.4))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // 촬영 버튼 영역
                VStack(spacing: 12) {
                    if isRecording {
                        Text(String(format: "%.1f초", remainingTime))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text("탭하여 촬영")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.4), lineWidth: 4)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(isRecording ? .red : .white)
                            .frame(width: 64, height: 64)

                        if isRecording {
                            Circle()
                                .trim(from: 0, to: CGFloat((2.0 - remainingTime) / 2.0))
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    .onTapGesture {
                        guard !isRecording else { return }
                        startRecording()
                    }
                }
                .padding(.bottom, 60)
            }

            // 토스트
            if showToast {
                VStack {
                    Spacer()
                    Text(String(format: "%02d시 클립이 저장됐습니다", hour))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 160)
                }
                .transition(.opacity)
            }

            // 에러
            if let errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.red.opacity(0.8))
                        .clipShape(Capsule())
                        .padding(.bottom, 160)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { recordingService.startSession() }
        .onDisappear { recordingService.stopSession() }
    }

    private func startRecording() {
        isRecording = true
        remainingTime = 2.0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            remainingTime = max(0, remainingTime - 0.1)
        }

        Task {
            do {
                let clipPath = try await recordingService.startRecording(hour: hour, dayRouteID: dayRoute.id)
                await MainActor.run {
                    timer?.invalidate()
                    timer = nil
                    isRecording = false
                    saveClip(path: clipPath)
                }
            } catch {
                await MainActor.run {
                    timer?.invalidate()
                    timer = nil
                    isRecording = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveClip(path: String) {
        var paths = dayRoute.diaryClipPaths
        if !paths.contains(path) {
            paths.append(path)
            dayRoute.diaryClipPaths = paths
            try? modelContext.save()
        }
        withAnimation { showToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                withAnimation { showToast = false }
                router.pop()
            }
        }
    }
}

// MARK: - 카메라 프리뷰

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
