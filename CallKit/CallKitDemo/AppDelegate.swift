//
//  AppDelegate.swift
//  CallKitDemo
//
//  Created by Xi Huang on 6/5/17.
//  Copyright © 2017 Tokbox, Inc. All rights reserved.
//

import UIKit
import PushKit
import CallKit
import OpenTok

let apiKey = "48048351"
let sessionId = "2_MX40ODA0ODM1MX5-MTc0OTE5NTY2MTc5NX5naDd3LzJDVDBOMTlTYmZHWDhTWDVqa2l-fn4"
let token = "T1==cGFydG5lcl9pZD00ODA0ODM1MSZzaWc9ZjhiZWUyMjE0ZjY1YzUxODI3ODRkZWRmYTFkMWUyOWIyYmE5ODYxNDpzZXNzaW9uX2lkPTJfTVg0ME9EQTBPRE0xTVg1LU1UYzBPVEU1TlRZMk1UYzVOWDVuYURkM0x6SkRWREJPTVRsVFltWkhXRGhUV0RWcWEybC1mbjQmY3JlYXRlX3RpbWU9MTc0OTIwNDAwNSZub25jZT0wLjMyNDM2MjM2MTYzNDkyODA0JnJvbGU9bW9kZXJhdG9yJmV4cGlyZV90aW1lPTE3NDkyMDU4MDM5MTImaW5pdGlhbF9sYXlvdXRfY2xhc3NfbGlzdD0="

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    let pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
    let callManager = SpeakerboxCallManager()
    var providerDelegate: ProviderDelegate?

    // Trigger VoIP registration on launch
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let sessionManager = OTAudioDeviceManager.currentAudioSessionManager()
        sessionManager?.enableCallingServicesMode()
        
        providerDelegate = ProviderDelegate(callManager: callManager, sessionManager: sessionManager)
        
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        
        return true
    }
}

extension AppDelegate: PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        print("\(#function) voip token: \(credentials.token)")
        
        let deviceToken = credentials.token.reduce("", {$0 + String(format: "%02X", $1) })
        print("\(#function) token is: \(deviceToken)")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        
        print("\(#function) incoming voip notfication: \(payload.dictionaryPayload)")
        if let uuidString = payload.dictionaryPayload["UUID"] as? String,
            let handle = payload.dictionaryPayload["handle"] as? String,
            let uuid = UUID(uuidString: uuidString) {
                            
            // display incoming call UI when receiving incoming voip notification
            let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
            self.displayIncomingCall(uuid: uuid, handle: handle, hasVideo: false) { _ in
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("\(#function) token invalidated")
    }
        
    /// Display the incoming call to the user
    func displayIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false, completion: ((NSError?) -> Void)? = nil) {
        providerDelegate?.reportIncomingCall(uuid: uuid, handle: handle, hasVideo: hasVideo, completion: completion)
    }
}
