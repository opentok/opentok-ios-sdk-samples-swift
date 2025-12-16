import UIKit
import SwiftUI
import AVFAudio

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Configure AVAudioSession early to avoid route/mode race conditions with AURemoteIO.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("AVAudioSession setup failed: \(error)")
        }

        // Build a minimal CallViewModel with placeholder credentials.

        var applicationId = "47521351"
        var sessionId = "2_MX40NzUyMTM1MX5-MTc2NTg5NjAyMDgyOX5HZG5tamwxaTArbk1SUklOVkkxZlNxR2N-fn4"
        var token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI0NzUyMTM1MSIsImlzdCI6InByb2plY3QiLCJpYXQiOjE3NjU4OTYwMjYsImV4cCI6MTc2ODQ4ODAyNiwic2Vzc2lvbl9pZCI6IjJfTVg0ME56VXlNVE0xTVg1LU1UYzJOVGc1TmpBeU1EZ3lPWDVIWkc1dGFtd3hhVEFyYmsxU1VrbE9Wa2t4WmxOeFIyTi1mbjQiLCJjcmVhdGVfdGltZSI6MTc2NTg5NjAyNiwibm9uY2UiOjAuMzM1MDAxMzU4NTA2NzYwNCwicm9sZSI6InB1Ymxpc2hlciIsImV4cGlyZV90aW1lIjoxNzY4NDg4MDI2LCJpbml0aWFsX2xheW91dF9jbGFzc19saXN0IjoiIiwic2NvcGUiOiJzZXNzaW9uLmNvbm5lY3QifQ._YzMH9zmc1iq--QS51fX5RD8IK5FoX013iJ6R9UJaRs"

        let credentials = ConsultationCredentials(applicationId: applicationId, sessionId: sessionId, token: token)
        let state = AppointmentState(pollResult: .joinTCVideoSuccess(credentials))
        let viewModel = CallViewModel(appointmentState: state)!

        let rootView = CallView(viewModel: viewModel) {
            // onFinish handler: dismiss or do nothing for now
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: rootView)
        window.makeKeyAndVisible()
        self.window = window

        return true
    }
}
