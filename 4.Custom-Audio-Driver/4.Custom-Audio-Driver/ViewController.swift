//
//  ViewController.swift
//  Custom-Audio-Driver
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok

let kWidgetHeight = 240
let kWidgetWidth = 320

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
let kApiKey = ""
// Replace with your generated session ID
let kSessionId = ""
// Replace with your generated token
let kToken = ""


class ViewController: UIViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)
    }()
    
    var publisher: OTPublisher?
    var subscriber: OTSubscriber?
    
    // Change to `false` to subscribe to streams other than your own.
    var subscribeToSelf = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        doConnect()
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    private func doConnect() {
        defer {
            process(error: error)
        }
        var error: OTError?
        session.connect(withToken: kToken, error: &error)
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session. OTPubilsher
     * binds to the device camera and microphone, and will provide A/V streams
     * to the OpenTok session.
     */
    fileprivate func doPublish() {
        defer {
            process(error: error)
        }
        publisher = OTPublisher(delegate: self, name: UIDevice.current.name)        
        var error: OTError? = nil
        session.publish(publisher, error: &error)
        publisher!.view.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
        view.addSubview(publisher!.view)
    }
    
    fileprivate func process(error err: OTError?) {
        if let e = err {
            showAlert(errorStr: e.localizedDescription)
        }
    }
    
    fileprivate func showAlert(errorStr err: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: "Error", message: err, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(controller, animated: true, completion: nil)
        }
    }
}

// MARK: - OTSession delegate callbacks
extension ViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession!) {
        print("Session connected")        
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession!) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession!, streamCreated stream: OTStream!) {
        print("Session streamCreated: \(stream.streamId)")
    }
    
    func session(_ session: OTSession!, streamDestroyed stream: OTStream!) {
        print("Session streamDestroyed: \(stream.streamId)")
    }
    
    func session(_ session: OTSession!, didFailWithError error: OTError!) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit!, streamCreated stream: OTStream!) {
    }
    
    func publisher(_ publisher: OTPublisherKit!, streamDestroyed stream: OTStream!) {
    }
    
    func publisher(_ publisher: OTPublisherKit!, didFailWithError error: OTError!) {
        print("Publisher failed: \(error.localizedDescription)")
    }
    
}

