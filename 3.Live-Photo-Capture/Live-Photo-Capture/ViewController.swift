//
//  ViewController.swift
//  Lets-Build-OTPublisher
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
    
    var publisher: ExamplePublisher?
    
    var subscriber: OTSubscriber?
    
    // Change to `false` to subscribe to streams other than your own.
    var subscribeToSelf = true
    let captureSession = AVCaptureSession()
    
    let captureQueue = dispatch_queue_create("com.tokbox.VideoCapture", DISPATCH_QUEUE_SERIAL)
    let photoVideoCapture = ExamplePhotoVideoCapture()
    
    var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView = UIImageView(frame: CGRect(x: 0, y: kWidgetHeight, width: kWidgetWidth, height: kWidgetHeight))
        imageView.backgroundColor = UIColor.greenColor()
        view.addSubview(imageView)
        
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleSingleTap(_:)))
        view.addGestureRecognizer(singleTap)
        
        doConnect()
    }
    
    func handleSingleTap(gestureRecognizer: UIGestureRecognizer) {
        photoVideoCapture.takePhoto { (photo) in
            self.imageView.image = photo
            self.imageView.setNeedsDisplay()
        }
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    private func doConnect() {
        defer {
            processError(error)
        }
        var error: OTError?
        session.connectWithToken(kToken, error: &error)
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session. OTPubilsher
     * binds to the device camera and microphone, and will provide A/V streams
     * to the OpenTok session.
     */
    private func doPublish() {
        defer {
            processError(error)
        }
        publisher = ExamplePublisher(delegate: self, name: UIDevice.currentDevice().name)
        publisher?.videoCapture = photoVideoCapture
        var error: OTError? = nil
        session.publish(publisher, error: &error)
        publisher!.view.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
        view.addSubview(publisher!.view)
    }
    
    private func processError(error: OTError?) {
        if let err = error {
            showAlert(errorStr: err.localizedDescription)
        }
    }
    
    private func showAlert(errorStr err: String) {
        dispatch_async(dispatch_get_main_queue()) {
            let controller = UIAlertController(title: "Error", message: err, preferredStyle: .Alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }
}

// MARK: - OTSession delegate callbacks
extension ViewController: OTSessionDelegate {
    func sessionDidConnect(session: OTSession!) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(session: OTSession!) {
        print("Session disconnected")
    }
    
    func session(session: OTSession!, streamCreated stream: OTStream!) {
        print("Session streamCreated: \(stream.streamId)")
    }
    
    func session(session: OTSession!, streamDestroyed stream: OTStream!) {
        print("Session streamDestroyed: \(stream.streamId)")
    }
    
    func session(session: OTSession!, didFailWithError error: OTError!) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(publisher: OTPublisherKit!, streamCreated stream: OTStream!) {
    }
    
    func publisher(publisher: OTPublisherKit!, streamDestroyed stream: OTStream!) {
    }
    
    func publisher(publisher: OTPublisherKit!, didFailWithError error: OTError!) {
        print("Publisher failed: \(error.localizedDescription)")
    }
    
}

