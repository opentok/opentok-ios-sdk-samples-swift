/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Model class representing a single call
*/

import Foundation
import OpenTok
import CallKit

final class SpeakerboxCall: NSObject {

    // MARK: Metadata Properties

    let uuid: UUID
    let isOutgoing: Bool
    var handle: String?

    // MARK: Call State Properties

    var connectingDate: Date? {
        didSet {
            stateDidChange?()
            hasStartedConnectingDidChange?()
        }
    }
    var connectDate: Date? {
        didSet {
            stateDidChange?()
            hasConnectedDidChange?()
        }
    }
    var endDate: Date? {
        didSet {
            stateDidChange?()
            hasEndedDidChange?()
        }
    }
    var isOnHold = false {
        didSet {
            stateDidChange?()
        }
    }
    
    var isMuted = false {
        didSet {
            publisher?.publishAudio = !isMuted
        }
    }

    // MARK: State change callback blocks

    var stateDidChange: (() -> Void)?
    var hasStartedConnectingDidChange: (() -> Void)?
    var hasConnectedDidChange: (() -> Void)?
    var hasEndedDidChange: (() -> Void)?
    var audioChange: (() -> Void)?
    var callDidEnd: ((CXCallEndedReason) -> Void)?
    
    // MARK: Derived Properties

    var hasStartedConnecting: Bool {
        get {
            return connectingDate != nil
        }
        set {
            connectingDate = newValue ? Date() : nil
        }
    }
    var hasConnected: Bool {
        get {
            return connectDate != nil
        }
        set {
            connectDate = newValue ? Date() : nil
        }
    }
    var hasEnded: Bool {
        get {
            return endDate != nil
        }
        set {
            endDate = newValue ? Date() : nil
        }
    }
    var duration: TimeInterval {
        guard let connectDate = connectDate else {
            return 0
        }

        return Date().timeIntervalSince(connectDate)
    }

    // MARK: Initialization

    init(uuid: UUID, isOutgoing: Bool = false) {
        self.uuid = uuid
        self.isOutgoing = isOutgoing
    }

    // MARK: Actions
    var session: OTSession?
    var publisher: OTPublisher?
    var subscriber: OTSubscriber?
    
    func assertSessionParams() {
        assert(!apiKey.isEmpty, "Empty API key, session will not be instantiated")
        assert(!sessionId.isEmpty, "Empty Session ID, session will not be instantiated")
        assert(!token.isEmpty, "Empty token, session will not connect")
    }
    
    var canStartCall: ((Bool) -> Void)?
    func startCall(withAudioSession audioSession: AVAudioSession, completion: ((_ success: Bool) -> Void)?) {
        if session == nil {
            assertSessionParams()
            session = OTSession(apiKey: apiKey, sessionId: sessionId, delegate: self)
        }
        canStartCall = completion
        
        var error: OTError?
        hasStartedConnecting = true
        session?.connect(withToken: token, error: &error)
        if let error = error {
            print(error)
            callDidEnd?(.failed)
        }
    }
    
    var canAnswerCall: ((Bool) -> Void)?
    func answerCall(withAudioSession audioSession: AVAudioSession, completion: ((_ success: Bool) -> Void)?) {
        if session == nil {
            assertSessionParams()
            session = OTSession(apiKey: apiKey, sessionId: sessionId, delegate: self)
        }
        
        canAnswerCall = completion
        
        var error: OTError?
        hasStartedConnecting = true
        session?.connect(withToken: token, error: &error)
        if let error = error {
            print(error)
            callDidEnd?(.failed)
        }
    }
    
    func startAudio() {
        if publisher == nil {
            let settings = OTPublisherSettings()
            settings.name = UIDevice.current.name
            settings.audioTrack = true
            settings.videoTrack = false
            publisher = OTPublisher(delegate: self, settings: settings)
        }
        
        var error: OTError?
        session?.publish(publisher!, error: &error)
        if let error = error {
            print(error)
            
            if let session = session {
                var error: OTError?
                session.disconnect(&error)
                if let error = error {
                    print(error)
                }
            }
            
            callDidEnd?(.failed)
        }
    }
    
    func endCall() {
        /*
         Simulate the end taking effect immediately, since
         the example app is not backed by a real network service
         */
        if let publisher = publisher {
            var error: OTError?
            session?.unpublish(publisher, error: &error)
            if error != nil {
                print(error!)
            }
        }
        publisher = nil
        
        if let session = session {
            var error: OTError?
            session.disconnect(&error)
            if let error = error {
                print(error)
            }
        }
        session = nil
        
        hasEnded = true
    }
}

extension SpeakerboxCall: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print(#function)
        
        hasConnected = true
        canStartCall?(true)
        canAnswerCall?(true)
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print(#function)
    }
    
    func sessionDidBeginReconnecting(_ session: OTSession) {
        print(#function)
    }
    
    func sessionDidReconnect(_ session: OTSession) {
        print(#function)
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print(#function, error)
        
        hasConnected = false
        canStartCall?(false)
        canAnswerCall?(false)
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print(#function)
        subscriber = OTSubscriber.init(stream: stream, delegate: self)
        subscriber?.subscribeToVideo = false
        if let subscriber = subscriber {
            var error: OTError?
            session.subscribe(subscriber, error: &error)
            if error != nil {
                print(error!)
            }
        }
    }
    
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print(#function)
    }
}

extension SpeakerboxCall: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print(#function)
        callDidEnd?(.failed)
    }
}

extension SpeakerboxCall: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriber: OTSubscriberKit) {
        print(#function)
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print(#function)
        callDidEnd?(.failed)
    }
}
