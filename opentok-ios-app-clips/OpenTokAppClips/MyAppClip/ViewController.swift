//
//  ViewController.swift
//  MyAppClip
//
//  Created by Jerónimo Valli on 8/27/20.
//

import UIKit
import WebKit
import StoreKit
import OpenTok

class ViewController: UIViewController {

    var webView: WKWebView?
    var session: OTSession?
    var publisher: OTPublisher?
    var subscriber: OTSubscriber?
    var apiKey: String?
    var sessionId: String?
    var token: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView = WKWebView(frame: view.bounds)
        guard let webView = webView else { return }
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        view.addSubview(webView)
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0.0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0.0).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0.0).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0.0).isActive = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let windowSceneDelegate = windowScene.delegate as? SceneDelegate,
           let currentUrl = windowSceneDelegate.userActivityWebpageURL,
           !currentUrl.absoluteString.isEmpty {
            let request = URLRequest(url: currentUrl)
            print("URL loaded: \(currentUrl.absoluteString)")
            webView?.load(request)
            if let storedApiKey = windowSceneDelegate.apiKey,
               let storedSessionId = windowSceneDelegate.sessionId,
               let storedToken = windowSceneDelegate.token {
                print("apiKey: \(storedApiKey)")
                print("sessionId: \(storedSessionId)")
                print("token: \(storedToken)")
                apiKey = storedApiKey
                sessionId = storedSessionId
                token = storedToken
                webView?.stopLoading()
                webView?.removeFromSuperview()
                connectToAnOpenTokSession()
            }
        }
        displayOverlay()
    }
    
    func displayOverlay() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let config = SKOverlay.AppClipConfiguration(position: .bottom)
        let overlay = SKOverlay(configuration: config)
        overlay.present(in: windowScene)
    }
    
    func connectToAnOpenTokSession() {
        guard let apiKey = apiKey,
            let sessionId = sessionId,
            let token = token else {
            return
        }
        session = OTSession(apiKey: apiKey, sessionId: sessionId, delegate: self)
        var error: OTError?
        session?.connect(withToken: token, error: &error)
        if let error = error {
            print(error)
        }
    }
    
    func publishStreamToSession() {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        guard let publisher = OTPublisher(delegate: self, settings: settings) else {
            return
        }

        var error: OTError?
        session?.publish(publisher, error: &error)
        if let error = error {
            print(error)
            return
        }

        guard let publisherView = publisher.view else {
            return
        }
        let screenBounds = UIScreen.main.bounds
        publisherView.frame = CGRect(x: screenBounds.width - 150 - 20, y: screenBounds.height - 150 - 20, width: 150, height: 150)
        view.addSubview(publisherView)
    }
    
    func subscribeToStream(_ stream: OTStream) {
        subscriber = OTSubscriber(stream: stream, delegate: self)
        guard let subscriber = subscriber else {
            return
        }

        var error: OTError?
        session?.subscribe(subscriber, error: &error)
        if let error = error {
            print(error)
            return
        }

        guard let subscriberView = subscriber.view else {
            return
        }
        subscriberView.frame = UIScreen.main.bounds
        view.insertSubview(subscriberView, at: 0)
    }
}

// MARK: - OTSessionDelegate callbacks
extension ViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("The client connected to the OpenTok session.")
        publishStreamToSession()
    }

    func sessionDidDisconnect(_ session: OTSession) {
        print("The client disconnected from the OpenTok session.")
    }

    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("The client failed to connect to the OpenTok session: \(error).")
    }

    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("A stream was created in the session.")
        subscribeToStream(stream)
    }

    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("A stream was destroyed in the session.")
    }
}

// MARK: - OTPublisherDelegate callbacks
extension ViewController: OTPublisherDelegate {
   func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
       print("The publisher failed: \(error)")
   }
}

// MARK: - OTSubscriberDelegate callbacks
extension ViewController: OTSubscriberDelegate {
   public func subscriberDidConnect(toStream subscriber: OTSubscriberKit) {
       print("The subscriber did connect to the stream.")
   }

   public func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
       print("The subscriber failed to connect to the stream.")
   }
}

extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let windowSceneDelegate = windowScene.delegate as? SceneDelegate,
           let url = windowSceneDelegate.userActivityWebpageURL {
            let alert = UIAlertController(title: "App Clips", message: "Webpage loaded from App Clip: \(url.absoluteString)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}
