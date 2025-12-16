//
//  CallViewModel.swift
//  Teleclinic
//
//  Created on 16/08/24.
//  Copyright © 2024 Teleclinic GmbH. All rights reserved.
//

import Combine
import OpenTok
import AVFAudio

private enum LogLevel: String {
    case info
    case error
}

enum CallError: Error {
    case connectionDisrupted
    case vonage(OTError)

    var message: String {
        switch self {
        case .connectionDisrupted: "videoCallViewConnectionDisrupted"
        case .vonage(let error): error.localizedDescription
        }
    }
}

public struct ConsultationCredentials {
    public let applicationId: String
    public let sessionId: String
    public let token: String

    public init(applicationId: String, sessionId: String, token: String) {
        self.applicationId = applicationId
        self.sessionId = sessionId
        self.token = token
    }
}

public enum AppointmentPollResult {
    case joinTCVideoSuccess(ConsultationCredentials)
}

public struct AppointmentState {
    public let pollResult: AppointmentPollResult

    public init(pollResult: AppointmentPollResult) {
        self.pollResult = pollResult
    }
}

@MainActor
class CallViewModel: NSObject, ObservableObject {

    let appointmentState: AppointmentState
    let consultationCredentials: ConsultationCredentials

    @Published private(set) var error: CallError?
    @Published private(set) var focusModeEnabled = false
    @Published private(set) var finished = false
    @Published private(set) var debugLogMessages: [String] = []
    @Published var presentErrorAlert = false
    @Published var presentFinishAlert = false

    // New lifecycle flags to synchronize stress routine
    @Published private(set) var didSessionConnect = false
    @Published private(set) var didPublisherStart = false

    private(set) nonisolated(unsafe) var session: OTSession?
    private(set) nonisolated(unsafe) var publisher: OTPublisher?
    private(set) nonisolated(unsafe) var subscribers: [OTSubscriber] = []
    private(set) nonisolated(unsafe) var subscriberDisconnected = false
    private(set) var reconnect = false
    private(set) var sessionStatusObserver: NSKeyValueObservation?

    // Used by triggerRerenderView() as a trigger to make sure the view gets rerendered.
    // See also comment on triggerRerenderView().
    @Published private var rerenderViewTrigger = 0

    init?(appointmentState: AppointmentState) {
        guard case .joinTCVideoSuccess(let consultationCredentials) = appointmentState.pollResult else { return nil }
        self.appointmentState = appointmentState
        self.consultationCredentials = consultationCredentials
        super.init()
    }

    var isAudioEnabled: Bool {
        publisher?.publishAudio ?? false
    }

    var isVideoEnabled: Bool {
        publisher?.publishVideo ?? false
    }

    func connect() {
        // reset flags for a fresh run
        didSessionConnect = false
        didPublisherStart = false

        guard let session = createSession() else { return }
        self.session = session
        triggerRerenderView()

        sessionStatusObserver = session.observe(\.sessionConnectionStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.triggerRerenderView()
            }
        }

        var otError: OTError?
        session.connect(withToken: consultationCredentials.token, error: &otError)
        if let otError {
            log(.error, "Session connect error: (code: \(otError.code), message: \(otError.localizedDescription))")
            setError(.vonage(otError))
        }
    }

    func promptFinishAlert() {
        presentFinishAlert = true
    }

    func hangUp() {
        disconnect()
        finished = true
    }

    func flipCamera() {
        guard let publisher else { return }
        switch publisher.cameraPosition {
        case .back:
            publisher.cameraPosition = .front
        case .front:
            publisher.cameraPosition = .back
        default:
            return
        }
    }

    func toggleAudio() {
        guard let publisher else { return }
        publisher.publishAudio.toggle()
        triggerRerenderView()
    }

    func toggleVideo() {
        guard let publisher else { return }
        publisher.publishVideo.toggle()
        triggerRerenderView()
    }

    func toggleFocus() {
        focusModeEnabled.toggle()
    }

}

// Simple logger to replace missing 'logger'
fileprivate struct SimpleLogger {
    func info(_ message: String, file: String?, function: String?, line: Int?, column: Int?) {
        print("[INFO] \(message)")
    }
    func error(_ message: String, file: String?, function: String?, line: Int?, column: Int?) {
        print("[ERROR] \(message)")
    }
}
fileprivate let logger = SimpleLogger()

// Minimal string constants used by CallView.swift
struct Strings {
    static let videoCallConnectionClosed = "Connection closed"
    static let generalGenericError = "Something went wrong"
    static let videoCallViewHangUp = "Hang up"
    static let videoCallStayInCall = "Stay in call"
    static let videoCallViewEndCall = "End call?"
    static let generalYes = "Yes"
    static let generalNo = "No"
}

private extension CallViewModel {

    nonisolated func log(
        _ logLevel: LogLevel,
        _ message: String,
        file: String? = #fileID,
        function: String? = #function,
        line: Int? = #line,
        column: Int? = #column
    ) {
        switch logLevel {
        case .info: logger.info(message, file: file, function: function, line: line, column: column)
        case .error: logger.error(message, file: file, function: function, line: line, column: column)
        }

#if DEBUGMENU
        Task { @MainActor in
            debugLogMessages.append("\(Date.now.formatted(date: .omitted, time: .standard)) [\(logLevel.rawValue)] - \(message)")
        }
#endif
    }

    func createSession() -> OTSession? {
        let settings = OTSessionSettings()
        let iceConfig = OTSessionICEConfig()
        iceConfig.transportPolicy = .relay
        settings.iceConfig = iceConfig

        return OTSession(
            apiKey: consultationCredentials.applicationId, // fixed label
            sessionId: consultationCredentials.sessionId,
            delegate: self,
            settings: settings
        )
    }

    func disconnect(reconnect: Bool = false) {
        guard let session else { return }

        if reconnect, session.sessionConnectionStatus == .connected {
            self.reconnect = true
            log(.info, "Reconnecting")
        }

        switch session.sessionConnectionStatus {
        case .connected, .connecting, .reconnecting:
            var otError: OTError?
            session.disconnect(&otError)
            if let otError {
                log(.error, "Session disconnect error: (code: \(otError.code), message: \(otError.localizedDescription))")
            }
        case .notConnected, .disconnecting, .failed:
            break
        @unknown default:
            break
        }
    }

    func onDisconnect() {
        publisher = nil
        subscribers = []
        triggerRerenderView()

        // reset flags after teardown
        didSessionConnect = false
        didPublisherStart = false

        if reconnect {
            reconnect = false
            connect()
        } else {
            subscriberDisconnected = false

            if !presentErrorAlert, !presentFinishAlert {
                finished = true
            }
        }
    }

    func publish() {
        // Pre-activate audio session prior to publisher creation to reduce AURemoteIO onboarding glitches.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            log(.error, "AVAudioSession activation failed: \(error)")
        }

        guard let session else { return }
        guard publisher == nil else { return }
        let settings = OTPublisherSettings()
        settings.name = "Patient"
        guard let publisher = OTPublisher(delegate: self, settings: settings) else { return }
        var otError: OTError?
        session.publish(publisher, error: &otError)
        if let otError {
            log(.error, "Publish error: (code: \(otError.code), message: \(otError.localizedDescription))")
            setError(.vonage(otError))
        } else {
            self.publisher = publisher
        }
        triggerRerenderView()
    }

    nonisolated func subscribe(_ stream: OTStream) {
        guard let session else { return }
        guard let subscriber = OTSubscriber(stream: stream, delegate: self) else { return }
        var otError: OTError?
        session.subscribe(subscriber, error: &otError)
        if let otError {
            log(.error, "Subscribe error: (code: \(otError.code), message: \(otError.localizedDescription))")
        } else {
            subscribers.append(subscriber)
        }
        Task { @MainActor in
            if let otError {
                setError(.vonage(otError))
            }
            triggerRerenderView()
        }
    }

    func setError(_ error: CallError) {
        self.error = error
        presentErrorAlert = true
    }

    /// Call when non-published vonage related objects changed and that change affects what the view renders.
    /// The view will then be triggered to be rerendered.
    func triggerRerenderView() {
        rerenderViewTrigger = rerenderViewTrigger
    }

}

// Make the stress routine await the flags rather than sleeping
extension CallViewModel {
    func stressSessionLifecycle(iterations: Int = 100, timeoutMs: Int = 2_000) {
        Task.detached { [weak self] in
            guard let self else { return }
            for i in 1...iterations {
                await MainActor.run { self.log(.info, "Stress run \(i): connect"); self.connect() }

                // Wait until sessionDidConnect sets didSessionConnect or timeout
                if !(await self.waitForFlag(\.didSessionConnect, timeoutMs: timeoutMs)) {
                    await MainActor.run { self.log(.error, "Stress run \(i): session connect timeout") }
                } else {
                    await MainActor.run { self.log(.info, "Stress run \(i): session connected") }
                }

                // publish() is called in sessionDidConnect already; wait for publisher streamCreated
                if !(await self.waitForFlag(\.didPublisherStart, timeoutMs: timeoutMs)) {
                    await MainActor.run { self.log(.error, "Stress run \(i): publisher start timeout") }
                } else {
                    await MainActor.run { self.log(.info, "Stress run \(i): publisher started") }
                }

                await disconnect()
            }
            await MainActor.run { self.log(.info, "StressSessionLifecycle finished") }
        }
    }

    // Generic waiter for a @Published Bool flag with timeout
    private func waitForFlag(_ keyPath: KeyPath<CallViewModel, Bool>, timeoutMs: Int) async -> Bool {
        let start = Date()
        while true {
            // Check flag on MainActor
            let flag = await MainActor.run { self[keyPath: keyPath] }
            if flag { return true }
            // Timeout
            if Date().timeIntervalSince(start) * 1000.0 >= Double(timeoutMs) { return false }
            // Small yield to avoid busy loop; ~20ms
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

extension CallViewModel {
    func stressAudioSession() {
        Task.detached {
            let session = AVAudioSession.sharedInstance()
            for i in 0..<50 {
                do {
                    try session.setActive(false, options: [.notifyOthersOnDeactivation])
                    try session.setCategory(.playAndRecord, mode: (i % 2 == 0 ? .videoChat : .voiceChat), options: [.allowBluetooth, .defaultToSpeaker])
                    try session.setActive(true, options: [])
                } catch {
                    Task { @MainActor in
                        self.log(.error, "StressAudioSession step \(i) failed: \(error)")
                    }
                }
                usleep(50_000) // 50ms between reconfigurations
            }
            Task { @MainActor in
                self.log(.info, "StressAudioSession finished")
            }
        }
    }
}

extension CallViewModel: OTSessionDelegate {

    nonisolated func sessionDidConnect(_ session: OTSession) {
        log(.info, "OTSessionDelegate.sessionDidConnect")
        Task { @MainActor in
            didSessionConnect = true
            publish()
        }
    }

    nonisolated func sessionDidDisconnect(_ session: OTSession) {
        log(.info, "OTSessionDelegate.sessionDidDisconnect")
        Task { @MainActor in
            onDisconnect()
        }
    }

    nonisolated func session(_ session: OTSession, didFailWithError error: OTError) {
        log(.error, "OTSessionDelegate.didFailWithError (code: \(error.code), subscriberDisconnected: \(subscriberDisconnected))")
        Task { @MainActor in
            if subscriberDisconnected {
                setError(.connectionDisrupted)
            } else {
                setError(.vonage(error))
            }
        }
    }

    nonisolated func session(_ session: OTSession, streamCreated stream: OTStream) {
        log(.info, "OTSessionDelegate.streamCreated (stream: \(stream.streamId))")
        subscribe(stream)
    }

    nonisolated func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        log(.info, "OTSessionDelegate.streamDestroyed (stream: \(stream.streamId), subscriberDisconnected: \(subscriberDisconnected))")

        // When the vonage session disconnects, all subscribers get unsubscribed automatically.
        // However, when the subscriber stream gets destroyed but the session remains connected,
        // the unsubscribe does not happen (this happens when the doctor closes and reopens the tab for example).
        // If we wouldn't unsubscribe, vonage would keep the subscriber instance in memory
        // and start reporting errors for the destroyed stream.
        // Note that this seems like a vonage issue, it should always unsubscribe automatically.
        // And for publishers, it does unpublish when a publisher stream gets destroyed
        // (unpublishing would then even lead to an error "publisher not found").
        for subscriber in subscribers.filter({ $0.stream?.streamId == stream.streamId }) {
            var otError: OTError?
            session.unsubscribe(subscriber, error: &otError)
            if let otError {
                log(.error, "Unsubscribe error: (code: \(otError.code), message: \(otError.localizedDescription))")
            }
        }
        subscribers.removeAll(where: { $0.stream?.streamId == stream.streamId })

        Task { @MainActor in
            triggerRerenderView()
        }
    }

    nonisolated func session(_ session: OTSession, connectionCreated connection: OTConnection) {
        log(.info, "OTSessionDelegate.connectionCreated")
    }

    nonisolated func session(_ session: OTSession, connectionDestroyed connection: OTConnection) {
        log(.info, "OTSessionDelegate.connectionDestroyed")
    }

    nonisolated func session(_ session: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        log(.info, "OTSessionDelegate.receivedSignalType")
    }

    nonisolated func session(_ session: OTSession, archiveStartedWithId archiveId: String, name: String?) {
        log(.info, "OTSessionDelegate.archiveStartedWithId")
    }

    nonisolated func session(_ session: OTSession, archiveStoppedWithId archiveId: String) {
        log(.info, "OTSessionDelegate.archiveStoppedWithId")
    }

    nonisolated func sessionDidBeginReconnecting(_ session: OTSession) {
        log(.info, "OTSessionDelegate.sessionDidBeginReconnecting")
    }

    nonisolated func sessionDidReconnect(_ session: OTSession) {
        log(.info, "OTSessionDelegate.sessionDidReconnect")
    }

    nonisolated func session(_ session: OTSession, muteForced muteForcedInfo: OTMuteForcedInfo) {
        log(.info, "OTSessionDelegate.muteForced")
    }

}

extension CallViewModel: OTPublisherKitDelegate {

    nonisolated func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        let logParams = [
            "code: \(error.code)",
            "stream: \(publisher.stream?.streamId ?? "-")",
            "subscriberDisconnected: \(subscriberDisconnected)",
        ]
        log(.error, "OTPublisherDelegate.didFailWithError (\(logParams.joined(separator: ", ")))")

        Task { @MainActor in
            self.publisher = nil

            if subscriberDisconnected {
                setError(.connectionDisrupted)
            } else {
                setError(.vonage(error))
            }
        }
    }

    nonisolated func muteForced(_ publisher: OTPublisherKit) {
        log(.info, "OTPublisherDelegate.muteForced (stream: \(publisher.stream?.streamId ?? "-"))")
    }

    nonisolated func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        log(.info, "OTPublisherDelegate.streamCreated (stream: \(stream.streamId))")
        Task { @MainActor in
            didPublisherStart = true
            triggerRerenderView()
        }
    }

    nonisolated func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        log(.info, "OTPublisherDelegate.streamDestroyed (stream: \(stream.streamId), subscriberDisconnected: \(subscriberDisconnected))")

        Task { @MainActor in
            self.publisher = nil

            // When the doctor lost connection, the following would happen if we wouldn't do anything:
            // 1. OTSubscriberDelegate.subscriberDidDisconnect is called.
            // 2. OTPublisherDelegate.didFailWithError is called (~ 20 seconds later) with error 1610 (OTPublisherWebRTCError).
            // 3. OTPublisherDelegate.streamDestroyed is called at the same time.
            // 4. OTSubscriberDelegate.didFailWithError is called (~ 10 seconds later) with error 1600 (OTSubscriberWebRTCError).
            // 5. The Vonage server would consider the doctor client to be disconnected (~ 20 seconds later)
            //    and would notify the patient client about it:
            // 6. OTSessionDelegate.streamDestroyed + OTSessionDelegate.connectionDestroyed is called therefore.
            //
            // What happens when the doctor reconnects depends on WHEN the doctor reconnects:
            // - If the doctor reconnects after step 1, OTSubscriberDelegate.subscriberDidReconnect is called.
            //   Everything continues to work without problems, the doctor sees the patient and the patient sees the doctor.
            // - If the doctor reconnects after step 3, the patient publisher stream has already been destroyed.
            //   Therefore, the doctor won't see the patient anymore.
            //   The patient will still see the doctor, since the subscriber stream has not been destroyed.
            //   Note that this could potentially be fixed by publishing again when handling OTSubscriberDelegate.subscriberDidReconnect.
            // - If the doctor reconnects after step 4, both the patient publisher stream and the subscriber stream have been destroyed/stopped.
            //   Therefore, the doctor won't see the patient and the patient won't see the doctor anymore.
            //   Since the subscriber stream has been stopped, OTSubscriberDelegate.subscriberDidReconnect won't be called.
            //   In fact, no delegate method is called that would allow us to reestablish the streams.
            // - If the doctor reconnects (reload browser tab) after step 6, there will be a new connection (the old one was disconnected, no reconnect possible).
            //   Both the patient publisher stream and the subscriber stream have been destroyed.
            //   But since there is a new connection, OTSessionDelegate.streamCreated is called where we create a new subscriber.
            //   The patient publisher stream remains destroyed however.
            //   Therefore, the patient will see the doctor, but the doctor won't see the patient.
            //
            // In order to recover in ANY case (for when the doctor lost connection, not when the patient lost connection),
            // we disconnect and immediately reconnect again.
            // This way, we will always have a new working patient publisher stream
            // and OTSessionDelegate.streamCreated will always be called to allow us to have a new working subscriber as well.
            // As long as the Vonage server doesn't disconnect the doctor (step 5),
            // the patient Vonage client will try to establish a peer to peer connection to the doctor.
            // This can obviously fail (if the doctor still has no connection).
            // In this case, OTSubscriberDelegate.didFailWithError is called with error 1542 (OTConnectionTimedOut).
            // We then simply reconnect again (see OTSubscriberDelegate.didFailWithError delegate method).
            // This can repeat until the Vonage server disconnects the doctor (step 5).
            // From then on, we'll have a connected session with a patient publisher stream waiting for the doctor to connect.
            // As long as the Vonage server doesn't disconnect the doctor (step 5),
            // the patient Vonage client will try to establish a peer to peer connection to the doctor.
            // This can obviously fail (if the doctor still has no connection).
            // In this case, OTSubscriberDelegate.didFailWithError is called with error 1542 (OTConnectionTimedOut).
            // We then simply reconnect again (see OTSubscriberDelegate.didFailWithError delegate method).
            // This can repeat until the Vonage server disconnects the doctor (step 5).
            // From then on, we'll have a connected session with a patient publisher stream waiting for the doctor to connect.
            //
            // The patient will be informed about connection issues while handling OTPublisherDelegate.didFailWithError (step 2).
            // If the patient chooses to stay in the call (hoping for a reconnect of the doctor),
            // no further alert is shown to the patient until the doctor reconnects.
            //
            // An example log exempt should make this all more clear:
            //
            // 11:03:44.182 [INFO] OTSubscriberDelegate.subscriberDidDisconnect (stream: dc8efb02-c48d-4ab7-8fef-e84b1447b1b3)
            // 11:03:54.695 [INFO] OTSubscriberDelegate.subscriberDidDisconnect (stream: dc8efb02-c48d-4ab7-8fef-e84b1447b1b3)
            // >> OTSubscriberDelegate.subscriberDidDisconnect is for some reason always called twice
            // 11:04:04.258 [ERROR] OTPublisherDelegate.didFailWithError (code: 1610, stream: -, subscriberDisconnected: true)
            // >> Patient sees alert about connection problems
            // 11:04:04.258 [INFO] OTPublisherDelegate.streamDestroyed (stream: 80201DE4-E426-4E2C-AB0C-02774F96AAEF, subscriberDisconnected: true)
            // 11:04:04.258 [INFO] Reconnecting
            // 11:04:04.397 [INFO] OTSessionDelegate.connectionDestroyed
            // 11:04:04.446 [INFO] OTSessionDelegate.sessionDidDisconnect
            // 11:04:04.961 [INFO] OTSessionDelegate.sessionDidConnect
            // 11:04:04.961 [INFO] OTSessionDelegate.connectionCreated
            // >> Vonage server considers doctor client still connected (connectionCreated is for OTHER clients, not our own client) ...
            // 11:04:04.981 [INFO] OTSessionDelegate.streamCreated (stream: dc8efb02-c48d-4ab7-8fef-e84b1447b1b3)
            // >> ... and therefore the Vonage server tells our client that there is a doctor stream and we will try to subscribe to it
            // 11:04:04.990 [INFO] OTPublisherDelegate.streamCreated (stream: E67BD641-A9A6-4C11-B2EF-15E3E5D8A950)
            // 11:04:34.188 [ERROR] OTSubscriberDelegate.didFailWithError (code: 1542, stream: dc8efb02-c48d-4ab7-8fef-e84b1447b1b3, subscriberDisconnected: true)
            // >> The doctor has still no connection, the subscription fails therefore and we reconnect again
            // 11:04:34.189 [INFO] Reconnecting
            // 11:04:34.214 [INFO] OTPublisherDelegate.streamDestroyed (stream: E67BD641-A9A6-4C11-B2EF-15E3E5D8A950, subscriberDisconnected: true)
            // >> The disconnect (of the reconnect) also destroys the publisher stream. Worth to note that we don't initiate yet another reconnect (!reconnect check).
            // 11:04:34.215 [INFO] OTSessionDelegate.connectionDestroyed
            // 11:04:34.215 [INFO] OTSessionDelegate.sessionDidDisconnect
            // 11:04:34.894 [INFO] OTSessionDelegate.sessionDidConnect
            // 11:04:34.894 [INFO] OTSessionDelegate.connectionCreated
            // 11:04:34.894 [INFO] OTSessionDelegate.streamCreated (stream: dc8efb02-c48d-4ab7-8fef-e84b1447b1b3)
            // 11:04:34.919 [INFO] OTPublisherDelegate.streamCreated (stream: 9427D43B-B56E-4909-B925-1B00F1C23D04)
            // 11:04:38.349 [INFO] OTSessionDelegate.streamDestroyed (stream: dc8efb02-c48d-4ab7-8fef-e84b1447b1b3, subscriberDisconnected: true)
            // >> Vonage server considers doctor client disconnected and notifies us that the subscriber stream is destroyed.
            // >> There won't be any further subscriber stream error 1542 (OTConnectionTimedOut), since the subscriber stream is destroyed.
            // 11:04:38.349 [INFO] OTSessionDelegate.connectionDestroyed
            // >> Vonage server notifies us that the doctor client no longer exists.
            // 11:05:18.584 [INFO] OTSessionDelegate.connectionCreated
            // >> Doctor reconnected (reloading tab) and Vonage server notifies us that a new doctor client exists.
            // >> From here on it is basically the same as if the patient joined the video call first and the doctor second.
            // 11:05:18.643 [INFO] OTSessionDelegate.streamCreated (stream: 96d63b7a-f13f-47b7-b31c-2d13d849842b)
            // 11:05:19.433 [INFO] OTSubscriberDelegate.subscriberDidConnect (stream: 96d63b7a-f13f-47b7-b31c-2d13d849842b)
            if subscriberDisconnected, let session, session.sessionConnectionStatus == .connected, !reconnect {
                disconnect(reconnect: true)
            }

            triggerRerenderView()
        }
    }

}

extension CallViewModel: OTSubscriberKitDelegate {

    nonisolated func subscriberDidConnect(toStream subscriber: OTSubscriberKit) {
        log(.info, "OTSubscriberDelegate.subscriberDidConnect (stream: \(subscriber.stream?.streamId ?? "-"))")
        Task { @MainActor in
            subscriberDisconnected = false
            triggerRerenderView()
        }
    }

    nonisolated func subscriberDidDisconnect(fromStream subscriber: OTSubscriberKit) {
        log(.info, "OTSubscriberDelegate.subscriberDidDisconnect (stream: \(subscriber.stream?.streamId ?? "-"))")
        Task { @MainActor in
            subscriberDisconnected = true
            triggerRerenderView()
        }
    }

    nonisolated func subscriberDidReconnect(toStream subscriber: OTSubscriberKit) {
        log(.info, "OTSubscriberDelegate.subscriberDidReconnect (stream: \(subscriber.stream?.streamId ?? "-"))")
        Task { @MainActor in
            subscriberDisconnected = false
            triggerRerenderView()
        }
    }

    nonisolated func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        let logParams = [
            "code: \(error.code)",
            "stream: \(subscriber.stream?.streamId ?? "-")",
            "subscriberDisconnected: \(subscriberDisconnected)",
        ]
        log(.error, "OTSubscriberDelegate.didFailWithError (\(logParams.joined(separator: ", ")))")

        subscribers.removeAll(where: { $0 === subscriber })

        Task { @MainActor in
            let errorCode = OTSubscriberErrorCode(rawValue: Int32(error.code))

            if errorCode == .OTConnectionTimedOut, subscriberDisconnected, let session, session.sessionConnectionStatus == .connected {
                disconnect(reconnect: true)
            } else if subscriberDisconnected {
                setError(.connectionDisrupted)
            } else {
                setError(.vonage(error))
            }
        }
    }

    nonisolated func subscriberVideoDisabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        log(.info, "OTSubscriberDelegate.subscriberVideoDisabled (stream: \(subscriber.stream?.streamId ?? "-"))")
    }

    nonisolated func subscriberVideoEnabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        log(.info, "OTSubscriberDelegate.subscriberVideoEnabled (stream: \(subscriber.stream?.streamId ?? "-"))")
    }

    nonisolated func subscriberVideoDisableWarning(_ subscriber: OTSubscriberKit) {
        log(.info, "OTSubscriberDelegate.subscriberVideoDisableWarning (stream: \(subscriber.stream?.streamId ?? "-"))")
    }

    nonisolated func subscriberVideoDisableWarningLifted(_ subscriber: OTSubscriberKit) {
        log(.info, "OTSubscriberDelegate.subscriberVideoDisableWarningLifted (stream: \(subscriber.stream?.streamId ?? "-"))")
    }

}
