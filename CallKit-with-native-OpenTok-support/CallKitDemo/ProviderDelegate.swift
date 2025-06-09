/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	CallKit provider delegate class, which conforms to CXProviderDelegate protocol
*/

import Foundation
import UIKit
import CallKit
import AVFoundation
import OpenTok
import Combine

final class ProviderDelegate: NSObject, CXProviderDelegate {

    let callManager: SpeakerboxCallManager
    private let provider: CXProvider
    private let sessionManager: OTAudioSessionManager?
    let muteSubject = PassthroughSubject<Bool, Never>()
    private var cancellable: AnyCancellable?

    init(callManager: SpeakerboxCallManager, sessionManager: OTAudioSessionManager?) {
        self.callManager = callManager
        self.sessionManager = sessionManager
        provider = CXProvider(configuration: type(of: self).providerConfiguration)

        super.init()

        provider.setDelegate(self, queue: nil)

        setupMuteThrottle()
    }
    
    /// The app's provider configuration, representing its CallKit capabilities
    static var providerConfiguration: CXProviderConfiguration {
        let localizedName = NSLocalizedString("CallKitDemo", comment: "Name of application")
        let providerConfiguration = CXProviderConfiguration(localizedName: localizedName)

        providerConfiguration.supportsVideo = false
        
        providerConfiguration.maximumCallsPerCallGroup = 1
        
        providerConfiguration.maximumCallGroups = 1
        
        providerConfiguration.supportedHandleTypes = [.phoneNumber]

        providerConfiguration.iconTemplateImageData = #imageLiteral(resourceName: "IconMask").pngData()

        providerConfiguration.ringtoneSound = "Ringtone.caf"
        
        return providerConfiguration
    }

    // MARK: Incoming Calls

    /// Use CXProvider to report the incoming call to the system
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false, completion: ((NSError?) -> Void)? = nil) {
        // Construct a CXCallUpdate describing the incoming call, including the caller.
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = hasVideo
        update.supportsHolding = true
        
        // pre-heat the AVAudioSession
        // Report the incoming call to the system
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            /*
                Only add incoming call to the app's list of calls if the call was allowed (i.e. there was no error)
                since calls may be "denied" for various legitimate reasons. See CXErrorCodeIncomingCallError.
             */
            if error == nil {
                let call = SpeakerboxCall(uuid: uuid)
                call.handle = handle

                self.callManager.addCall(call)
            }
            
            completion?(error as NSError?)
        }
    }

    // MARK: CXProviderDelegate

    func providerDidBegin(_ provider: CXProvider) {
        print("Provider did begin")
    }
    
    func providerDidReset(_ provider: CXProvider) {
        print("Provider did reset")
        /*
            End any ongoing calls if the provider resets, and remove them from the app's list of calls,
            since they are no longer valid.
         */
    }

    var outgoingCall: SpeakerboxCall?
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("Received perform CXStartCallAction \(action.callUUID)")
        // Create & configure an instance of SpeakerboxCall, the app's model class representing the new outgoing call.
        let call = SpeakerboxCall(uuid: action.callUUID, isOutgoing: true)
        call.handle = action.handle.value

        /*
            Configure the audio session, but do not start call audio here, since it must be done once
            the audio session has been activated by the system after having its priority elevated.
         */
        // https://forums.developer.apple.com/thread/64544
        // we can't configure the audio session here for the case of launching it from locked screen
        // instead, we have to pre-heat the AVAudioSession by configuring as early as possible, didActivate do not get called otherwise
        // please look for  * pre-heat the AVAudioSession *
        sessionManager?.preconfigureAudioSessionForCall(withMode: .voiceChat)
        
        /*
            Set callback blocks for significant events in the call's lifecycle, so that the CXProvider may be updated
            to reflect the updated state.
         */
        call.hasStartedConnectingDidChange = { [weak self] in
            self?.setupHold(to: call.uuid)
            self?.provider.reportOutgoingCall(with: call.uuid, startedConnectingAt: call.connectingDate)
        }
        call.hasConnectedDidChange = { [weak self] in
            self?.provider.reportOutgoingCall(with: call.uuid, connectedAt: call.connectDate)
        }
        call.callDidEnd = { [weak self] reason in
            self?.provider.reportCall(with: call.uuid, endedAt: nil, reason: reason)
        }
        self.outgoingCall = call
        
        // Signal to the system that the action has been successfully performed.
        action.fulfill()
    }

    var answerCall: SpeakerboxCall?
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("Received perform CXAnswerCallAction")
        // Retrieve the SpeakerboxCall instance corresponding to the action's call UUID
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }

        /*
            Configure the audio session, but do not start call audio here, since it must be done once
            the audio session has been activated by the system after having its priority elevated.
         */
        
        // https://forums.developer.apple.com/thread/64544
        // we can't configure the audio session here for the case of launching it from locked screen
        // instead, we have to pre-heat the AVAudioSession by configuring as early as possible, didActivate do not get called otherwise
        // please look for  * pre-heat the AVAudioSession *
        sessionManager?.preconfigureAudioSessionForCall(withMode: .voiceChat)
        
        self.answerCall = call
        
        call.callDidEnd = { [weak self] reason in
            self?.provider.reportCall(with: call.uuid, endedAt: Date(), reason: reason)
        }
        
        // Signal to the system that the action has been successfully performed.
        action.fulfill()
    }

    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("Received perform CXEndCallAction")
        // Retrieve the SpeakerboxCall instance corresponding to the action's call UUID
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }

        // Trigger the call to be ended via the underlying network service.
        call.endCall()

        // Signal to the system that the action has been successfully performed.
        action.fulfill()

        call.stateDidChange = nil
        call.hasStartedConnectingDidChange = nil
        call.hasConnectedDidChange = nil
        call.hasEndedDidChange = nil
        call.audioChange = nil
        call.callDidEnd = nil
        
        // Remove the ended call from the app's list of calls.
        callManager.removeCall(call)
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("Received perform CXSetHeldCallAction \(action.isOnHold)")
        // Retrieve the SpeakerboxCall instance corresponding to the action's call UUID
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }

        // Update the SpeakerboxCall's underlying hold state.
        call.isOnHold = action.isOnHold

        // Stop or start audio in response to holding or unholding the call.
        updateMuteState(call.isOnHold)
        
        // Signal to the system that the action has been successfully performed.
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("Received perform CXSetMutedCallAction \(action.isMuted)")
        
        updateMuteState(action.isMuted)
        
        action.fulfill()
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print("Timed out \(#function)")

        // React to the action timeout if necessary, such as showing an error UI.
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("Received didActivate")
        sessionManager?.audioSessionDidActivate(audioSession)
        
        // If we are returning from a hold state
        if answerCall?.hasConnected ?? false {
            return
        }
        if outgoingCall?.hasConnected ?? false {
            return
        }
        
        // Start call audio media, now that the audio session has been activated after having its priority boosted.
        outgoingCall?.startCall(withAudioSession: audioSession) { [weak self] success in
            guard let outgoingCall = self?.outgoingCall else { return }
            if success {
                self?.callManager.addCall(outgoingCall)
                self?.outgoingCall?.startAudio()
            } else {
                self?.callManager.end(call: outgoingCall)
            }
        }
        
        answerCall?.answerCall(withAudioSession: audioSession) { success in
            if success {
                self.answerCall?.startAudio()
            }
        }
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("Received didDeactivate")
        sessionManager?.audioSessionDidDeactivate(audioSession)
        
        /*
             Restart any non-call related audio now that the app's audio session has been
             de-activated after having its priority restored to normal.
         */
        if outgoingCall?.isOnHold ?? false || answerCall?.isOnHold ?? false {
            print("Call is on hold. Do not terminate any call")
            return
        }
        
        outgoingCall?.endCall()
        outgoingCall = nil
        answerCall?.endCall()
        answerCall = nil
        callManager.removeAllCalls()
    }
    
    // MARK: Helpers
    
    func setupHold(to callUUID: UUID) {
        let update = CXCallUpdate()
        update.supportsHolding = true
        update.hasVideo = false
        provider.reportCall(with: callUUID, updated: update)
    }
    
    func setupMuteThrottle() {
        cancellable = muteSubject
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] isMuted in
                self?.applyMuteState(isMuted)
            }
    }
    
    func updateMuteState(_ isMuted: Bool) {
        muteSubject.send(isMuted)
    }
    
    private func applyMuteState(_ isMuted: Bool) {
        print("applyMuteState \(isMuted)")
        answerCall?.isMuted = isMuted
        outgoingCall?.isMuted = isMuted
    }
}
