import AVFoundation
import Foundation

enum MicrophonePermissionState: Equatable {
    case undetermined
    case granted
    case denied

    var isGranted: Bool { self == .granted }
}

/// Directive alias for Trust & Safety recording permission surface.
typealias RecordingPermissionState = MicrophonePermissionState

/// Local in-trip audio capture to a temporary file (Trust & Safety Module 3).
/// Recording is kept on-device; callers decide retention when a trip ends.
@MainActor
final class TripAudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordingURL: URL?
    @Published private(set) var permissionDenied = false
    @Published private(set) var permissionState: MicrophonePermissionState = .undetermined
    @Published private(set) var lastErrorMessage: String?

    private var recorder: AVAudioRecorder?

    var hasRecordingFile: Bool {
        guard let recordingURL else { return false }
        return FileManager.default.fileExists(atPath: recordingURL.path)
    }

    func refreshPermissionState() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            permissionState = .granted
            permissionDenied = false
        case .denied:
            permissionState = .denied
            permissionDenied = true
        case .undetermined:
            permissionState = .undetermined
            permissionDenied = false
        @unknown default:
            permissionState = .denied
            permissionDenied = true
        }
    }

    /// Prefers `PermissionCenter` when provided; otherwise uses `AVAudioSession` directly.
    func requestMicrophoneAccess(using permissions: PermissionCenter? = nil) async -> Bool {
        if let permissions {
            await permissions.requestMicrophone()
            let granted = permissions.microphoneAuthorized
            permissionState = granted ? .granted : (permissions.microphoneDenied ? .denied : .undetermined)
            permissionDenied = permissions.microphoneDenied
            return granted
        }

        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            permissionState = .granted
            permissionDenied = false
            return true
        case .denied:
            permissionState = .denied
            permissionDenied = true
            return false
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            permissionState = granted ? .granted : .denied
            permissionDenied = !granted
            return granted
        @unknown default:
            permissionState = .denied
            permissionDenied = true
            return false
        }
    }

    @discardableResult
    func startRecording(using permissions: PermissionCenter? = nil) async -> Bool {
        lastErrorMessage = nil
        if isRecording { return true }

        let granted = await requestMicrophoneAccess(using: permissions)
        guard granted else {
            lastErrorMessage = permissionDenied
                ? "Safety recording is unavailable. Enable Microphone for Vuum in Settings."
                : "Microphone access is required to record trip audio."
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            lastErrorMessage = "Could not prepare the microphone."
            return false
        }

        let url = makeTempRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: SafetyAutoActivation.AudioQuality.current().sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: SafetyAutoActivation.AudioQuality.current().encoderQuality,
        ]

        do {
            let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder.isMeteringEnabled = false
            guard audioRecorder.prepareToRecord(), audioRecorder.record() else {
                lastErrorMessage = "Could not start recording."
                try? FileManager.default.removeItem(at: url)
                return false
            }
            deleteFileIfNeeded(recordingURL)
            recorder = audioRecorder
            recordingURL = url
            isRecording = true
            return true
        } catch {
            lastErrorMessage = "Could not start recording."
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }

    func stopRecording() {
        guard isRecording || recorder != nil else { return }
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Removes the temp recording file from disk.
    func deleteRecording() {
        stopRecording()
        deleteFileIfNeeded(recordingURL)
        recordingURL = nil
        lastErrorMessage = nil
    }

    /// Stops capture but leaves the file in place for incident retention.
    func retainRecordingFile() {
        stopRecording()
    }

    private func makeTempRecordingURL() -> URL {
        let name = "vuum-trip-audio-\(UUID().uuidString).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private func deleteFileIfNeeded(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
