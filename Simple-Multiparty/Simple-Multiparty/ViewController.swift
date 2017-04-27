//
//  ViewController.swift
//  6.Multi-Party
//
//  Created by Roberto Perez Cubero on 27/09/2016.
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

class ViewController: UIViewController {

    @IBOutlet var endCallButton: UIButton!
    @IBOutlet var swapCameraButton: UIButton!
    @IBOutlet var muteMicButton: UIButton!
    @IBOutlet var userName: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    
    var subscribers: [IndexPath: OTSubscriber] = [:]
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    lazy var publisher: OTPublisher = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)!
    }()
    var error: OTError?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        session.connect(withToken: kToken, error: &error)
        
        userName.text = UIDevice.current.name
    }
    
    override func viewDidAppear(_ animated: Bool) {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        layout.itemSize = CGSize(width: collectionView.bounds.size.width / 2,
                                 height: collectionView.bounds.size.height / 2)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func swapCameraAction(_ sender: AnyObject) {
        if publisher.cameraPosition == .front {
            publisher.cameraPosition = .back
        } else {
            publisher.cameraPosition = .front
        }
    }
    
    @IBAction func tokboxButtonAction(_ sender: AnyObject) {
        
        UIApplication.shared.open(URL(string: "https://www.tokbox.com/developer/")!, options: [:], completionHandler: nil)
    }
    
    @IBAction func muteMicAction(_ sender: AnyObject) {
        publisher.publishAudio = !publisher.publishAudio
        
        let buttonImage: UIImage  = {
            if !publisher.publishAudio {
                return #imageLiteral(resourceName: "mic_muted-24")
            } else {
                return #imageLiteral(resourceName: "mic-24")
            }
        }()
        
        muteMicButton.setImage(buttonImage, for: .normal)
    }
    
    @IBAction func endCallAction(_ sender: AnyObject) {
        session.disconnect(&error)
    }
    
    func reloadCollectionView() {
        collectionView.isHidden = subscribers.count == 0
        collectionView.reloadData()
    }
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return subscribers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "subscriberCell", for: indexPath) as! SubscriberCollectionCell
        cell.subscriber = subscribers[indexPath]
        return cell
    }
}

extension ViewController: UICollectionViewDelegate {
}

// MARK: - Subscriber Cell
class SubscriberCollectionCell: UICollectionViewCell {
    @IBOutlet var muteButton: UIButton!
    
    var subscriber: OTSubscriber?
    
    @IBAction func muteSubscriberAction(_ sender: AnyObject) {
        subscriber?.subscribeToAudio = !(subscriber?.subscribeToAudio ?? true)
        
        let buttonImage: UIImage  = {
            if !(subscriber?.subscribeToAudio ?? true) {
                return #imageLiteral(resourceName: "Subscriber-Speaker-Mute-35")
            } else {
                return #imageLiteral(resourceName: "Subscriber-Speaker-35")
            }
        }()
        
        muteButton.setImage(buttonImage, for: .normal)
    }
    
    override func layoutSubviews() {
        if let sub = subscriber, let subView = sub.view {
            subView.frame = bounds
            contentView.insertSubview(subView, belowSubview: muteButton)
            
            muteButton.isEnabled = true
            muteButton.isHidden = false
        }
    }
}

// MARK: - OpenTok Methods
extension ViewController {
    func doPublish() {
        swapCameraButton.isEnabled = true
        muteMicButton.isEnabled = true
        endCallButton.isEnabled = true
        
        if let pubView = publisher.view {
            let publisherDimensions = CGSize(width: view.bounds.size.width / 4,
                                             height: view.bounds.size.height / 6)
            pubView.frame = CGRect(origin: CGPoint(x:collectionView.bounds.size.width - publisherDimensions.width,
                                                   y:collectionView.bounds.size.height - publisherDimensions.height + collectionView.frame.origin.y),
                                   size: publisherDimensions)
            view.addSubview(pubView)
            
        }
        
        session.publish(publisher, error: &error)
    }
    
    func doSubscribe(to stream: OTStream) {
        if let subscriber = OTSubscriber(stream: stream, delegate: self) {
            let indexPath = IndexPath(item: subscribers.count, section: 0)
            subscribers[indexPath] = subscriber
            session.subscribe(subscriber, error: &error)
            
            reloadCollectionView()
        }
    }
    
    func findSubscriber(byStreamId id: String) -> (IndexPath, OTSubscriber)? {
        for (_, entry) in subscribers.enumerated() {
            if let stream = entry.value.stream, stream.streamId == id {
                return (entry.key, entry.value)
            }
        }
        return nil
    }
    
    func findSubscriberCell(byStreamId id: String) -> SubscriberCollectionCell? {
        for cell in collectionView.visibleCells {
            if let subscriberCell = cell as? SubscriberCollectionCell,
                let subscriberOfCell = subscriberCell.subscriber,
                (subscriberOfCell.stream?.streamId ?? "") == id
            {
                return subscriberCell
            }
        }
        
        return nil
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
        subscribers.removeAll()
        reloadCollectionView()
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        if subscribers.count == 4 {
            print("Sorry this sample only supports up to 4 subscribers :)")
            return
        }
        doSubscribe(to: stream)
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        
        guard let (index, subscriber) = findSubscriber(byStreamId: stream.streamId) else {
            return
        }
        subscriber.view?.removeFromSuperview()
        subscribers.removeValue(forKey: index)
        reloadCollectionView()
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

// MARK: - OTSubscriber delegate callbacks
extension ViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("Subscriber connected")
        reloadCollectionView()
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}

