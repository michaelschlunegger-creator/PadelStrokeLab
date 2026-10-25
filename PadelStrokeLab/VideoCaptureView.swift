import AVFoundation
import PadelDesign
import SwiftUI
import UIKit

/// Preparation component only. Application navigation is enabled in the later
/// orchestration/deletion package; this view grants no owner or Watch authority.
struct VideoCaptureView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var capture: PhoneVideoCapture

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PracticeTheme.Space.large) {
                Text("Frame your practice").font(.largeTitle.bold())
                Text("Place your iPhone securely in landscape with the rear camera facing you. Keep Padel Master open.")
                    .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                if capture.isPreviewReady, let session = capture.previewSession {
                    PhoneCameraPreview(session: session)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 16))
                        .accessibilityLabel("Rear camera preview")
                }
                Label(status, systemImage: capture.isCaptureRequested ? "record.circle" : "camera")
                    .font(.headline).accessibilityIdentifier("phoneCameraStatus")
                if let error = capture.lastError {
                    Text(error).foregroundStyle(PracticeTheme.secondaryInk(scheme))
                }
                if capture.isCaptureRequested {
                    Button("Stop capture", role: .destructive) { Task { await capture.stop() } }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("phoneCameraEmergencyStop")
                } else if !capture.isPreviewReady {
                    Button("Prepare camera") { Task { try? await capture.preparePreview() } }
                        .buttonStyle(PracticeActionStyle()).disabled(capture.busy || capture.isStopping)
                        .accessibilityIdentifier("phoneCameraPrepare")
                }
            }
            .padding(PracticeTheme.Space.large)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(PracticeTheme.canvas(scheme))
        .foregroundStyle(PracticeTheme.ink(scheme))
        .tint(PracticeTheme.accent(scheme))
        .navigationTitle("Camera")
        .navigationBarBackButtonHidden(capture.isCaptureRequested)
        .task { await capture.setSceneActive(scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in Task { await capture.setSceneActive(phase == .active) } }
        .onDisappear { Task { await capture.close() } }
    }

    private var status: String {
        if capture.isAcquiring { return "Receiving video and audio" }
        if capture.isCaptureRequested { return "Waiting for video and audio" }
        if capture.isPreviewReady { return "Camera preview · Microphone inactive" }
        return "Camera stopped"
    }
}

private struct PhoneCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface(); view.previewLayer.videoGravity = .resizeAspect
        view.previewLayer.session = session; return view
    }
    func updateUIView(_ view: PreviewSurface, context: Context) {
        if view.previewLayer.session !== session { view.previewLayer.session = session }
    }
    static func dismantleUIView(_ view: PreviewSurface, coordinator: ()) { view.previewLayer.session = nil }
}

private final class PreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
