//
//  ViewController.swift
//  Hello-World
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = "28415832"
// Replace with your generated session ID
let kSessionId = "2_MX4yODQxNTgzMn5-MTcyNTA0ODQ5ODQzN35ueTZwWTl2WFAwM1AvMi82YUpPd2wzTkp-fn4"
// Replace with your generated token
let kToken = "T1==cGFydG5lcl9pZD0yODQxNTgzMiZzaWc9NGE0MDRiZjU4M2E4ODVlZTY5YWViZTFjMGEwZTliOWE1MDk0NDdiMzpzZXNzaW9uX2lkPTJfTVg0eU9EUXhOVGd6TW41LU1UY3lOVEEwT0RRNU9EUXpOMzV1ZVRad1dUbDJXRkF3TTFBdk1pODJZVXBQZDJ3elRrcC1mbjQmY3JlYXRlX3RpbWU9MTcyNTA0ODQ5OCZub25jZT0wLjE3NTUxMTYzNjkwMjkzMTI2JnJvbGU9bW9kZXJhdG9yJmV4cGlyZV90aW1lPTE3Mjc2NDA0OTgmaW5pdGlhbF9sYXlvdXRfY2xhc3NfbGlzdD0="

let kWidgetHeight = 240
let kWidgetWidth = 320

class ViewController: UIViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    var publisher: OTPublisherSync?
    var subscriber: OTSubscriber?
    
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
    func capturePublishingLifeCycle() async {
        do {
            let createdStream = try await publisher!.waitForStreamCreated()
            print("Stream created after await: \(createdStream)")
            session.unpublish(publisher!, error: nil)
            // After stream creation, you might want to wait for stream destruction
            
            publisher!.waitForStreamDestroyed { result in
                switch result {
                case .success(let stream):
                    print("Stream destroyed after await: \(stream)")
                case .failure(let error):
                    print("Error occurred after await: \(error)")
                }
            }
        } catch {
            print("Error occurred after await: \(error)")
        }
    }
    
    fileprivate func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        publisher =  OTPublisherSync(settings: settings)

        session.publish(publisher!, error: &error)
        
        if let pubView = publisher!.view {
            pubView.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(pubView)
        }
        Task {
            await self.capturePublishingLifeCycle()
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
        subscriber = OTSubscriber(stream: stream, delegate: self)
        
        session.subscribe(subscriber!, error: &error)
    }
    
    fileprivate func cleanupSubscriber() {
        subscriber?.view?.removeFromSuperview()
        subscriber = nil
    }
    
    fileprivate func cleanupPublisher() {
        publisher!.view?.removeFromSuperview()
        publisher = nil
    }
    
    fileprivate func processError(_ error: OTError?) {
        if let err = error {
            DispatchQueue.main.async {
                let controller = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(controller, animated: true, completion: nil)
            }
        }
    }
}

// MARK: - OTSession delegate callbacks
extension ViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
        cleanupPublisher()
        cleanupSubscriber()
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        if subscriber == nil {
            doSubscribe(stream)
        }
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing")
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        cleanupPublisher()
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

// MARK: - OTSubscriber delegate callbacks
extension ViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        if let subsView = subscriber?.view {
            subsView.frame = CGRect(x: 0, y: kWidgetHeight, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(subsView)
        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
}
