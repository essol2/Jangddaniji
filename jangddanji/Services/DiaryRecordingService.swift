import AVFoundation
import Foundation

@Observable
final class DiaryRecordingService: NSObject {
    var isSessionRunning = false
    var isRecording = false
    var error: DiaryRecordingError?

    let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var recordingContinuation: CheckedContinuation<String, Error>?
    private var outputURL: URL?

    // MARK: - 세션 시작

    func startSession() {
        guard !isSessionRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        // 후면 카메라
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            error = .cameraUnavailable
            return
        }
        captureSession.addInput(videoInput)

        // 마이크
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }

        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        captureSession.commitConfiguration()

        Task.detached(priority: .userInitiated) {
            self.captureSession.startRunning()
            await MainActor.run { self.isSessionRunning = true }
        }
    }

    // MARK: - 녹화 시작 (2초 후 자동 완료)

    func startRecording(hour: Int, dayRouteID: UUID) async throws -> String {
        guard !isRecording else { throw DiaryRecordingError.alreadyRecording }

        let url = clipURL(dayRouteID: dayRouteID, hour: hour)
        try? FileManager.default.removeItem(at: url) // 기존 파일 제거
        outputURL = url

        return try await withCheckedThrowingContinuation { continuation in
            self.recordingContinuation = continuation
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            self.isRecording = true

            Task {
                try? await Task.sleep(for: .seconds(2))
                self.movieOutput.stopRecording()
            }
        }
    }

    // MARK: - 세션 종료

    func stopSession() {
        guard isSessionRunning else { return }
        captureSession.stopRunning()
        isSessionRunning = false
    }

    // MARK: - 파일 경로

    private func clipURL(dayRouteID: UUID, hour: Int) -> URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DiaryClips/\(dayRouteID.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(hour).mov")
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension DiaryRecordingService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false
        if let error {
            recordingContinuation?.resume(throwing: error)
        } else {
            recordingContinuation?.resume(returning: outputFileURL.path)
        }
        recordingContinuation = nil
    }
}

// MARK: - Error

enum DiaryRecordingError: LocalizedError {
    case cameraUnavailable
    case alreadyRecording

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: return "카메라를 사용할 수 없습니다."
        case .alreadyRecording: return "이미 녹화 중입니다."
        }
    }
}
