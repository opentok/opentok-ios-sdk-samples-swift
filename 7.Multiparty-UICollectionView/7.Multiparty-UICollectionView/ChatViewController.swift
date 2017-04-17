//
//  ViewController.swift
//  7.Multiparty-UICollectionView
//
//  Created by Roberto Perez Cubero on 17/04/2017.
//  Copyright © 2017 tokbox. All rights reserved.
//

import UIKit
import OpenTok

/*
// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = ""
// Replace with your generated session ID
let kSessionId = ""
// Replace with your generated token
let kToken = ""
*/

// room: 0=0=
let kApiKey = "45328772"
let kToken = "T1==cGFydG5lcl9pZD00NTMyODc3MiZzaWc9Yjk4MGRkOGY0YzA2YWU5NmU2YmJlNjAyOTRmMDBiODc5MzE5ZWZlMzpzZXNzaW9uX2lkPTJfTVg0ME5UTXlPRGMzTW41LU1UUTVNalF5T0RBMU1UVTJObjQxZG0xQ1JsbFRlbFJrS3pKMWVGTk1jWGhwU0hsWGJIQi1mZyZjcmVhdGVfdGltZT0xNDkyNDI4MDUyJm5vbmNlPTAuMzA5ODM5MzQ0MTE3NzkwNDYmcm9sZT1wdWJsaXNoZXImZXhwaXJlX3RpbWU9MTQ5MjUxNDQ1MiZjb25uZWN0aW9uX2RhdGE9JTdCJTIydXNlck5hbWUlMjIlM0ElMjJBbm9ueW1vdXMlMjBVc2VyMjA1JTIyJTdE"
let kSessionId = "2_MX40NTMyODc3Mn5-MTQ5MjQyODA1MTU2Nn41dm1CRllTelRkKzJ1eFNMcXhpSHlXbHB-fg"


class ChatViewController: UICollectionViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    lazy var publisher: OTPublisher = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)!
    }()
        
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        doConnect()
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    fileprivate func doConnect() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.connect(withToken: kToken, error: &error)
    }

    /**
     * Sets up an instance of OTPublisher to use with this session. OTPubilsher
     * binds to the device camera and microphone, and will provide A/V streams
     * to the OpenTok session.
     */
    fileprivate func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.publish(publisher, error: &error)
        
        if let pubView = publisher.view {
            /*pubView.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(pubView)*/
        }
    }
    
    /**
     * Instantiates a subscriber for the given stream and asynchronously begins the
     * process to begin receiving A/V content for this stream. Unlike doPublish,
     * this method does not add the subscriber to the view hierarchy. Instead, we
     * add the subscriber only after it has connected and begins receiving data.
     */
    fileprivate func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            processError(error)
        }
        /*subscriber = OTSubscriber(stream: stream, delegate: self)
        
        session.subscribe(subscriber!, error: &error)*/
    }
    
    fileprivate func cleanupSubscriber(_ stream: OTStream) {
        /*subscriber?.view?.removeFromSuperview()
        subscriber = nil*/
    }
    
    fileprivate func processError(_ error: OTError?) {
        if let err = error {
            showAlert(errorStr: err.localizedDescription)
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
extension ChatViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        doSubscribe(stream)
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        cleanupSubscriber(stream)
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
}

// MARK: - OTPublisher delegate callbacks
extension ChatViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {        
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
    
}

