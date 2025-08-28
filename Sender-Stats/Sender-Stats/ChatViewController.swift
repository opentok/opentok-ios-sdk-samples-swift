//
//  ViewController.swift
//  Sender-Stats
//
//  Created by Artur Osinski on 27/08/2025.
//  Copyright © 2025 vonage. All rights reserved.
//

import UIKit
import OpenTok
import Foundation
//import

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = ""
// Replace with your generated session ID
let kSessionId = ""
// Replace with your generated token
let kToken = ""
let kApiRootURL = URL(string: "https://api.dev.opentok.com")
class ChatViewController: UICollectionViewController {
    
    enum Constant {
        static let maxBitrateText = "Max Bitrate (bps): "
        static let currentBitrateText = "Current Bitrate (bps): "
        static let showStatsText = "Show stats"
        static let hideStatsText = "Hide stats"
    }

    lazy var session: OTCustomSession = {
        guard let session = OTCustomSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self) else {
            fatalError("Please fill in the kApiKey, kSessionId & kToken")
        }
        return session
    }()
    
    /**
     *  **Sender stats step 1**
     *  OTPublisher object, needs setting senderStatisticsTrack to true
     *  in order to be able to send sender stats
     */
    lazy var publisher: OTPublisher = {
        let settings = OTPublisherSettings()
        settings.senderStatisticsTrack = true
        settings.name = UIDevice.current.name
        
        return OTPublisher(delegate: self, settings: settings)!
    }()
    
    var subscribers: [OTSubscriber] = []
    
    private lazy var statsButton: UIButton = {
        let statsButton = UIButton()
        statsButton.translatesAutoresizingMaskIntoConstraints = false
        statsButton.setTitle(
            Constant.showStatsText,
            for: .normal
        )
        statsButton.setTitleColor(.systemBlue, for: .normal)
        return statsButton
    }()
    
    private lazy var statsView: UIView = {
        let statsView = UIView()
        statsView.translatesAutoresizingMaskIntoConstraints = false
        statsView.backgroundColor = .lightText
        statsView.isHidden = true
        return statsView
    }()
    
    private lazy var maxBitrateLabel: UILabel = {
        let maxBitrateLabel = UILabel()
        maxBitrateLabel.translatesAutoresizingMaskIntoConstraints = false
        maxBitrateLabel.text = Constant.maxBitrateText + "N/A"
        return maxBitrateLabel
    }()
    
    private lazy var currentBitrateLabel: UILabel = {
        let currentBitrateLabel = UILabel()
        currentBitrateLabel.translatesAutoresizingMaskIntoConstraints = false
        currentBitrateLabel.text = Constant.currentBitrateText + "N/A"
        return currentBitrateLabel
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        session.setApiRootURL(kApiRootURL!)
        setupView()
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

        collectionView?.reloadData()
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
        guard let subscriber = OTSubscriber(stream: stream, delegate: self)
            else {
                print("Error while subscribing")
                return
        }
        
        /**
         * **Sender stats step 2**
         * Set the networkStatsDelegate to start receiving
         * OTSubscriberKitNetworkStatsDelegate callbacks for sender stats
         */
        subscriber.networkStatsDelegate = self
        session.subscribe(subscriber, error: &error)
        subscribers.append(subscriber)
        collectionView?.reloadData()
    }

    fileprivate func cleanupSubscriber(_ stream: OTStream) {
        subscribers = subscribers.filter { $0.stream?.streamId != stream.streamId }
        collectionView?.reloadData()
    }

    fileprivate func processError(_ error: OTError?) {
        guard let error else { return }
        showAlert(errorStr: error.localizedDescription)
    }

    fileprivate func showAlert(errorStr err: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: "Error", message: err, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    private func setupView() {
        view.addSubview(statsView)
        NSLayoutConstraint.activate([
            statsView.heightAnchor.constraint(equalToConstant: 80),
            statsView.widthAnchor.constraint(equalToConstant: 280),
            statsView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ])
        
        statsView.addSubview(maxBitrateLabel)
        statsView.addSubview(currentBitrateLabel)
        
        NSLayoutConstraint.activate([
            maxBitrateLabel.heightAnchor.constraint(equalToConstant: 25),
            maxBitrateLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 10),
            maxBitrateLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 10),
            maxBitrateLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: 10)
        ])
        
        NSLayoutConstraint.activate([
            currentBitrateLabel.heightAnchor.constraint(equalToConstant: 25),
            currentBitrateLabel.topAnchor.constraint(equalTo: maxBitrateLabel.bottomAnchor, constant: 10),
            currentBitrateLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 10),
            currentBitrateLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: 10)
        ])
        
        view.addSubview(statsButton)
        NSLayoutConstraint.activate([
            statsButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            statsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30)
        ])
        statsButton.addTarget(self, action: #selector(toggleStatsView), for: .touchUpInside)
    }
    
    @objc private func toggleStatsView() {
        statsView.isHidden.toggle()
        statsButton.setTitle(
            statsView.isHidden ? Constant.showStatsText : Constant.hideStatsText,
            for: .normal
        )
    }

    // MARK: - UICollectionView methods
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return subscribers.count + 1
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "videoCell", for: indexPath)
        let videoView: UIView? = {
            if (indexPath.row == 0) {
                return publisher.view
            } else {
                let sub = subscribers[indexPath.row - 1]
                return sub.view
            }
        }()

        if let viewToAdd = videoView {
            viewToAdd.frame = cell.bounds
            cell.addSubview(viewToAdd)
        }
        return cell
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

// MARK: - OTSubscriber delegate callbacks
extension ChatViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("Subscriber connected")
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}

// MARK: - OTSubscriberKitNetworkStatsDelegate callbacks
extension ChatViewController: OTSubscriberKitNetworkStatsDelegate {
    
    /**
     * **Sender stats step 3**
     * videoNetworkStatsUpdated method needs to be implemented
     * to capture information about sender stats as follows
     */
    func subscriber(_ subscriber: OTSubscriberKit, videoNetworkStatsUpdated stats: OTSubscriberKitVideoNetworkStats) {
        guard let senderStats = stats.senderStats else { return }
        maxBitrateLabel.text = Constant.maxBitrateText + "\(senderStats.maxBitrate)"
        currentBitrateLabel.text = Constant.currentBitrateText + "\(senderStats.currentBitrate)"
    }
}
