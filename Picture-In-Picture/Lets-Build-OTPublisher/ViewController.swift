//
//  ViewController.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok
import AVKit

let kWidgetRatio: CGFloat = 1.333

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = "47565621"
// Replace with your generated session ID
let kSessionId = "2_MX40NzU2NTYyMX5-MTcxNDYxNzE0MzkxMn5neE81RGhDTUM5YVNVY0s0bHI3Q0F0aEV-fn4"
// Replace with your generated token
let kToken = "T1==cGFydG5lcl9pZD00NzU2NTYyMSZzaWc9OTY4YWExZWZjNDQwMGZiMDJmOTI0ZGE2NDQwMDY1MjRjZWVjODA2ZTpzZXNzaW9uX2lkPTJfTVg0ME56VTJOVFl5TVg1LU1UY3hORFl4TnpFME16a3hNbjVuZUU4MVJHaERUVU01WVZOVlkwczBiSEkzUTBGMGFFVi1mbjQmY3JlYXRlX3RpbWU9MTcxNDYxNzE1MyZub25jZT0wLjAzNzU3Mzk0MDY1Njc0NTkxJnJvbGU9cHVibGlzaGVyJmV4cGlyZV90aW1lPTE3MTcyMDkxNTImaW5pdGlhbF9sYXlvdXRfY2xhc3NfbGlzdD0="



class ViewController: UIViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    var publisher: OTPublisher?
    
    var subscriber: OTSubscriber?
    
    var pipController: AVPictureInPictureController! = nil
    
    var pipObservation: NSKeyValueObservation?
        
    @IBOutlet weak var videoContainerView: UIView!
    
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
        
        session.publish(publisher!, error: &error)
         
         if let pubView = publisher!.view {
             pubView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.width / kWidgetRatio)
             view.addSubview(pubView)
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
        
        let videoRender = ExampleVideoRender()
        subscriber?.videoRender = videoRender
        
        session.subscribe(subscriber!, error: &error)
        
        pipSetup(videoRender: videoRender)
        
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
    
    fileprivate func pipSetup(videoRender: ExampleVideoRender) {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        
        let frame = CGRect(x: 0, y: view.frame.width / kWidgetRatio, width: view.frame.width, height: view.frame.width / kWidgetRatio)

        let bufferDisplayLayer = videoRender.bufferDisplayLayer
        bufferDisplayLayer.frame = frame

        bufferDisplayLayer.videoGravity = .resizeAspect
        videoContainerView.layer.addSublayer(bufferDisplayLayer)
        
        let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: videoRender.bufferDisplayLayer, playbackDelegate: self)
        
        
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController.delegate = self
        
        pipObservation = pipController.observe(\AVPictureInPictureController.isPictureInPicturePossible,
                                                options: [.initial, .new]) { [weak self] _, change in
            
            print("isPictureInPicturePossible: \(change.newValue ?? false)")
            
            self?.pipController.startPictureInPicture()
        }
    }
    
    @IBAction func startPIP(_ sender: Any) {
        pipController.startPictureInPicture()
    }
    
    
    @objc func appMovedToBackground() {
        print("app move to background", pipController.isPictureInPicturePossible)
        if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
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
//        subscriber?.view?.frame = CGRect(x: 0, y: view.frame.width / kWidgetRatio, width: view.frame.width, height: view.frame.width / kWidgetRatio)
        

        
//        if let subsView = subscriber?.view {
//            view.addSubview(subsView)
//        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate
extension ViewController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        print("\(#function)")
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        print("\(#function)")
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        print("\(#function)")
        return false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        print("\(#function)")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        print("\(#function)")
        completionHandler()
    }
}

// MARK: - AVPictureInPictureControllerDelegate
extension ViewController:AVPictureInPictureControllerDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("\(#function)")
        print("pip error: \(error)")
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("\(#function)")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("\(#function)")
    }
}

