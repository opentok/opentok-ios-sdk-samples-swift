//
//  SceneDelegate.swift
//  MyAppClip
//
//  Created by Jerónimo Valli on 8/27/20.
//

import UIKit
import AppClip

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var userActivityWebpageURL: URL?
    var apiKey: String?
    var sessionId: String?
    var token: String?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        if let activity = connectionOptions.userActivities.first {
            scene.delegate?.scene?(scene, continue: activity)
        }
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        print("willContinueUserActivityWithType: \(userActivityType)")
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard
            let incomingURL = userActivity.webpageURL,
            let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true)
        else {
            return
        }
        if let queryItems = components.queryItems {
            print("queryItems: \(queryItems)")
            for queryItem in queryItems {
                if queryItem.name == "apiKey" {
                    apiKey = queryItem.value
                }
                if queryItem.name == "sessionId" {
                    sessionId = queryItem.value
                }
                if queryItem.name == "token" {
                    token = queryItem.value
                }
            }
        }
        /*
        if #available(iOS 14.0, *) {
            if let payload = userActivity.appClipActivationPayload {
                print("appClipActivationPayload: \(payload)")
            }
        }
         */
        userActivityWebpageURL = incomingURL
    }
    
    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        print("didFailToContinueUserActivityWithType: \(userActivityType)")
        print("error: \(error)")
    }
}

