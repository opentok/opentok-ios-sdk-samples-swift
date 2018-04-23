//
//  ViewController.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok

let kWidgetRatio: CGFloat = 1.333

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = ""
// Replace with your generated session ID
let kSessionId = ""
// Replace with your generated token
let kToken = ""


class ViewController: UIViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    lazy var dateFormatter: DateFormatter = {
        let theDataFormatter = DateFormatter()
        theDataFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return theDataFormatter
    }()
    
    var publisher: OTPublisher?
    
    var subscriber: OTSubscriber?
    
    let captureSession = AVCaptureSession()
    
    @IBOutlet weak var metadataLabel: UILabel!
    
    
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
        var error: OTError? = nil
        defer {
            processError(error)
        }
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        
        publisher = OTPublisher(delegate: self, settings: settings)
        if let pub = publisher {
            let videoRender = ExampleVideoRender()
            videoRender.delegate = self
            let     videoCapture = ExampleVideoCapture()
            videoCapture.delegate = self
            pub.videoCapture = videoCapture
            pub.videoRender = videoRender
            session.publish(pub, error: &error)
            
            videoRender.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.width / kWidgetRatio)
            view.insertSubview(videoRender, at: 0)
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
    
    
    @IBAction func toggleCamera(_ sender: Any) {
        if let capturer = publisher?.videoCapture as? ExampleVideoCapture {
            let _ = capturer.toggleCameraPosition()
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
        subscriber?.view?.frame = CGRect(x: 0, y: view.frame.width / kWidgetRatio, width: view.frame.width, height: view.frame.width / kWidgetRatio)
        if let subsView = subscriber?.view {
            view.addSubview(subsView)
        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}

extension ViewController: ExampleVideoRenderDelegate {
    func renderer(_ renderer: ExampleVideoRender, didReceiveFrame videoFrame: OTVideoFrame) {
        guard let metadata = videoFrame.metadata, let timestampe = String(data: metadata, encoding: .utf8) else {
            print("Receiving video frame without metadata attached")
            return
        }
        
        DispatchQueue.main.async {
            self.metadataLabel.text = timestampe
            print("Receiving video frame metadata", timestampe)
        }
    }
}

/*
 * This piece is optional: we demonstrate how to attach a metadata to a video frame before transitmmiting to the OpenTok platform.
 * You don't have to attach a metadata to make the transmission work
 */
extension ViewController: FrameCapturerMetadataDelegate {
    func finishPreparingFrame(_ videoFrame: OTVideoFrame?) {
        guard let videoFrame = videoFrame else {
            return
        }
        setTimestampToVideoFrame(videoFrame)
    }
    
    fileprivate func setTimestampToVideoFrame(_ videoFrame: OTVideoFrame?) {
        guard let videoFrame = videoFrame else {
            return
        }
        
        let timestamp = self.dateFormatter.string(from: Date())

        let metdata = Data(timestamp.utf8)
        var error: OTError?
        videoFrame.setMetadata(metdata, error: &error)
        if let error = error {
            print(error)
        }
    }
}
