//
//  ViewController.swift
//  CallKitDemo
//
//  Created by Xi Huang on 6/5/17.
//  Copyright © 2017 Tokbox, Inc. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    fileprivate final let displayCaller = "Lucas Huang"
    fileprivate final let makeACallText = "Make a call"
    fileprivate final let unholdCallText = "Unhold Call"
    fileprivate final let simulateIncomingCallText = "Simulate Call"
    fileprivate final let simulateIncomingCallThreeSecondsText = "Simulate Call after 3s(Background)"
    fileprivate final let endCallText = "End call"

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleCallsChangedNotification(notification:)), name: SpeakerboxCallManager.CallsChangedNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var simulateCallButton: UIButton!
    @IBOutlet weak var simulateCallButton2: UIButton!
    
    @IBAction func receiveCallLucas(_ sender: UIButton) {
        guard let appdelegate = UIApplication.shared.delegate as? AppDelegate else {
            
            print("appdelegate is missing")
            return
        }
        
        if simulateCallButton.titleLabel?.text == simulateIncomingCallText {
            appdelegate.displayIncomingCall(uuid: UUID(), handle: displayCaller)
            sender.setTitle(endCallText, for: .normal)
            sender.setTitleColor(.red, for: .normal)
            callButton.isEnabled = false
            simulateCallButton2.isEnabled = false
        }
        else {
            endCall()
            sender.setTitle(simulateIncomingCallText, for: .normal)
            sender.setTitleColor(.white, for: .normal)
            callButton.isEnabled = true
            simulateCallButton2.isEnabled = true
        }
    }
    
    @IBAction func receiveCallLucasAfterThreeSeconds(_ sender: UIButton) {
        guard let appdelegate = UIApplication.shared.delegate as? AppDelegate else {
            
            print("appdelegate is missing")
            return
        }
        
        if sender.titleLabel?.text == simulateIncomingCallThreeSecondsText {
            
            let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                appdelegate.displayIncomingCall(uuid: UUID(), handle: "Lucas Huang", hasVideo: false) { _ in
                    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
            sender.setTitle(endCallText, for: .normal)
            sender.setTitleColor(.red, for: .normal)
            callButton.isEnabled = false
            simulateCallButton.isEnabled = false
        }
        else {
            endCall()
            sender.setTitle(simulateIncomingCallThreeSecondsText, for: .normal)
            sender.setTitleColor(.white, for: .normal)
            callButton.isEnabled = true
            simulateCallButton.isEnabled = true
        }
    }
    
    @IBAction func callButtonPressed(_ sender: UIButton) {
        guard let appdelegate = UIApplication.shared.delegate as? AppDelegate else {
            
            print("appdelegate is missing")
            return
        }
        
        if sender.titleLabel?.text == makeACallText {
            appdelegate.callManager.startCall(handle: displayCaller)
            sender.setTitle(endCallText, for: .normal)
            sender.setTitleColor(.red, for: .normal)
            simulateCallButton.isEnabled = false
            simulateCallButton2.isEnabled = false
        } else if sender.titleLabel?.text == unholdCallText { // This state set when user receives another call
            appdelegate.callManager.setHeld(call: appdelegate.callManager.calls[0], onHold: false)
        }
        else {
            endCall()
            sender.setTitle(makeACallText, for: .normal)
            sender.setTitleColor(.white, for: .normal)
            simulateCallButton.isEnabled = true
            simulateCallButton2.isEnabled = true
        }
    }
    
    @objc func handleCallsChangedNotification(notification: NSNotification) {
        guard let appdelegate = UIApplication.shared.delegate as? AppDelegate else {
            
            print("appdelegate is missing")
            return
        }

        if (appdelegate.callManager.calls.count > 0)
        {
            let call = appdelegate.callManager.calls[0]
            if call.isOnHold {
                callButton.setTitle(unholdCallText, for: .normal)
            } else if call.session != nil {
                callButton.setTitle(endCallText, for: .normal)
                callButton.setTitleColor(.red, for: .normal)
            }
            
            if let action = notification.userInfo?["action"] as? String, action == SpeakerboxCallManager.Call.end.rawValue {
                callButton.setTitle(makeACallText, for: .normal)
                callButton.setTitleColor(.white, for: .normal)
                callButton.isEnabled = true
                simulateCallButton.setTitle(simulateIncomingCallText, for: .normal)
                simulateCallButton.setTitleColor(.white, for: .normal)
                simulateCallButton.isEnabled = true
                simulateCallButton2.setTitle(simulateIncomingCallThreeSecondsText, for: .normal)
                simulateCallButton2.setTitleColor(.white, for: .normal)
                simulateCallButton2.isEnabled = true
            }
        }
    }
    
    fileprivate func endCall() {
        guard let appdelegate = UIApplication.shared.delegate as? AppDelegate else {
            
            print("appdelegate is missing")
            return
        }
        
        /*
         End any ongoing calls if the provider resets, and remove them from the app's list of calls,
         since they are no longer valid.
         */
        for call in appdelegate.callManager.calls {
            appdelegate.callManager.end(call: call)
        }
    }
}
