//
//  VonageVideo.swift
//  Signals
//
//  Created by Jaideep Shah on 2/15/23.
//

import UIKit
import OpenTok


let kApiKey = "28415832"
// Replace with your generated session ID
let kSessionId = "1_MX4yODQxNTgzMn5-MTY3NjUwMjQ4MzM3NH5SdU5vTVZPYkRGL1lIdjRtYy9yTUszdWh-fn4"
// Replace with your generated token
let kToken = "T1==cGFydG5lcl9pZD0yODQxNTgzMiZzaWc9YWQ1ZTQ0OGYxNjVkYWEzYmI3NTQ2YjRiNTE3NmZmYWJiZGYzZGUzMjpzZXNzaW9uX2lkPTFfTVg0eU9EUXhOVGd6TW41LU1UWTNOalV3TWpRNE16TTNOSDVTZFU1dlRWWlBZa1JHTDFsSWRqUnRZeTl5VFVzemRXaC1mbjQmY3JlYXRlX3RpbWU9MTY3NjUwMjQ4MyZub25jZT0wLjQxOTIzMjE5MDQwMDE4NjEmcm9sZT1tb2RlcmF0b3ImZXhwaXJlX3RpbWU9MTY3OTA5NDQ4MyZpbml0aWFsX2xheW91dF9jbGFzc19saXN0PQ=="


extension String {

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .ascii)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

}

class VonageVideo: NSObject {
    @Published var isSessionConnected = false
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    override init() {
        super.init()
        var error: OTError?
        session.connect(withToken: kToken, error: &error)
        if let error = error {
            print("Session creation error \(error.description)")
        }
    }
   
 }
// MARK: ObservableObject
extension VonageVideo: ObservableObject {

    
}
// MARK: - OTSession delegate callbacks
extension VonageVideo: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
       isSessionConnected = true
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
      
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
       
      
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
       
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("Session Failed to connect: \(error.localizedDescription)")
    }
    
    func session(_ session: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        if let string = string?.fromBase64() {
            print("received data \(string) from \(connection?.connectionId ?? "all")")
        }
    }
}

// MARK: - UI interface
extension VonageVideo {
   
    func sendSignalToAll(type: String?, data: String?) {
        let t  = (type ?? "Greetings !!").toBase64()
        let d = (data ?? "Hello World").toBase64()
        session.signal(withType: t , string: d, connection:nil, error: nil)
        print("signal send")
    }
}

