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

    // only letters permitted are (A-Z and a-z), numbers (0-9), "-", "_", " " and "~".
    // hence we encode and decode with base64
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .ascii)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
    
   // The maximum length of the type string is 128 characters, and it must
   // contain only letters (A-Z and a-z), numbers (0-9), "-", "_", " ", and "~".
   // you could have used base64 encoding decoding here. We went with a different approach here.
    func isValidSignal() -> Bool {
        return self.count <= 128 && self.range(of: "[^a-zA-Z0-9-_~] ", options: .regularExpression) == nil
    }
    func lastTenCharacter() -> String {
        return "..." + self.suffix(10)
    }
    
}

class VonageVideoSDK: NSObject {
    @Published var isSessionConnected = false
    @Published var connections: [OTConnection] = []
    var myConnection : String? = nil
    
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
extension VonageVideoSDK: ObservableObject {

    
}
// MARK: - OTSession delegate callbacks
extension VonageVideoSDK: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
       isSessionConnected = true
       connections.append(session.connection!)
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
      
    }
    
    func session(_ session: OTSession, connectionCreated connection: OTConnection) {
        connections.append(connection)
    }
    func session(_ session: OTSession, connectionDestroyed connection: OTConnection) {
        guard connections.contains(connection) else {
            return
        }
        connections = connections.filter { $0 != connection }
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
            print("received data \(string) from \(connection?.connectionId ?? "")")
        }
    }
}

// MARK: - UI interface
extension VonageVideoSDK {
   
    func sendSignalToAll(type: String?, data: String?) {
        let t  = (type ?? "Greetings !!").toBase64()
        let d = (data ?? "Hello World").toBase64()
        session.signal(withType: t , string: d, connection:nil, error: nil)
        print("signal send")
    }
    
    func closeAll() {
        session.disconnect(nil)
    }
    
    func isMyConnection(_ connection: OTConnection) -> Bool {
        return session.connection?.connectionId == connection.connectionId
    }
    func sendSignalToConnection(connection: String, type: String?, data: String?) {
        guard type?.isValidSignal() == true && data?.isValidSignal() == true else {
            return
        }
        let t  = type ?? "Greetings !!"
        let d = data ?? "Hello World"
        
        let conn = connections.filter { c in  // a rare bug can happen if the last 10 chars are matched in two connections
            return c.connectionId == connection
        }
        
        session.signal(withType: t , string: d, connection:conn.first, error: nil)
        print("signal send")
    }
}

