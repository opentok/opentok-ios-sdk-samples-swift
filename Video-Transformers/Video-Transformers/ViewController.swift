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
let kApiKey = ""
// Replace with your generated session ID
let kSessionId = ""
// Replace with your generated token
let kToken = ""

let kWidgetHeight = 240
let kWidgetWidth = 320

class CustomTransformer: NSObject, OTCustomVideoTransformer {
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    func transform(_ videoFrame: OTVideoFrame) {
        if let image = UIImage(named: "Vonage_Logo.png") {
            let yPlaneData = videoFrame.getPlaneBinaryData(0)
            let videoWidth = Int(videoFrame.format?.imageWidth ?? 0)
            let videoHeight = Int(videoFrame.format?.imageHeight ?? 0)
            
            // Calculate the desired size of the image
            let desiredWidth = CGFloat(videoWidth) / 8 // Adjust this value as needed
            let desiredHeight = image.size.height * (desiredWidth / image.size.width)
            
            // Resize the image to the desired size
            if let resizedImage = resizeImage(image, to: CGSize(width: desiredWidth, height: desiredHeight)) {
                let yPlane = yPlaneData
                
                // Create a CGContext from the Y plane
                guard let context = CGContext(data: yPlane,
                                              width: videoWidth,
                                              height: videoHeight,
                                              bitsPerComponent: 8,
                                              bytesPerRow: videoWidth,
                                              space: CGColorSpaceCreateDeviceGray(),
                                              bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                    return
                }
                
                // Location of the image (in this case right bottom corner)
                let x = CGFloat(videoWidth) * 4/5
                let y = CGFloat(videoHeight) * 1/5
                
                // Draw the resized image on top of the Y plane
                let rect = CGRect(x: x, y: y, width: desiredWidth, height: desiredHeight)
                context.draw(resizedImage.cgImage!, in: rect)
            }
        }
    }
}

class ViewController: UIViewController {
    
    var buttonVideoTransformerToggle: UIButton!
    
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    lazy var publisher: OTPublisher = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)!
    }()
    
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
    fileprivate func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.publish(publisher, error: &error)
        
        if error != nil {
            fatalError("An error occurred: \(String(describing: error))")
        }
        
        if let pubView = publisher.view {
            pubView.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(pubView)
        }
        
        // Configure toogle button
        buttonVideoTransformerToggle = UIButton(type: .custom)
        buttonVideoTransformerToggle.frame = CGRect(x: kWidgetWidth - 65, y: 50, width: 50, height: 25)
        buttonVideoTransformerToggle.layer.cornerRadius = 5.0
        self.view.addSubview(buttonVideoTransformerToggle)
        self.view.bringSubviewToFront(buttonVideoTransformerToggle)
        buttonVideoTransformerToggle.setTitle("set", for: .normal)
        buttonVideoTransformerToggle.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        buttonVideoTransformerToggle.setTitleColor(.gray, for: .normal)
        buttonVideoTransformerToggle.backgroundColor = .white
        buttonVideoTransformerToggle.layer.borderWidth = 1.0
        buttonVideoTransformerToggle.layer.borderColor = UIColor.gray.cgColor
        buttonVideoTransformerToggle.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

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
        publisher.view?.removeFromSuperview()
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
    
    let logoTransformer: CustomTransformer = CustomTransformer() // Create an instance of CustomTransformer

    @objc func buttonTapped(_ sender: UIButton) {
        if publisher.videoTransformers.isEmpty {
            // Create background blur Vonage transformer
            guard let backgroundBlur = OTVideoTransformer(name: "BackgroundBlur", properties: "{\"radius\":\"High\"}") else { return }
            // Create custom transformer
            guard let myCustomTransformer = OTVideoTransformer(name: "logo", transformer: logoTransformer)  else { return }

            var myVideoTransformers = [OTVideoTransformer]()

            myVideoTransformers.append(backgroundBlur)
            myVideoTransformers.append(myCustomTransformer)

            // Set video transformers to publisher video stream
            publisher.videoTransformers = myVideoTransformers

            buttonVideoTransformerToggle.setTitle("reset", for: .normal)
        } else {
            // Clear all transformers from video stream
            publisher.videoTransformers = []

            buttonVideoTransformerToggle.setTitle("set", for: .normal)
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
