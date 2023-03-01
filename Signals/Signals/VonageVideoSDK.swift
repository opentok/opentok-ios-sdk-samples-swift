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

struct SMessage: Identifiable {
    let id = UUID()
    var connId : String?
    var type: String
    var content: String
    var outgoing: Bool
    var displayConnId: String {
        get {
            return connId == nil ? "All" : connId!.lastTenCharacter()
        }
    }
}
struct ConnectionInfo : Equatable, Hashable {
    let id = UUID()
    var otConnectionHost : OTConnection
    var otConnectionParticipant : OTConnection?
    let displaySelf = "Self"
    
    static func ==(lhs: ConnectionInfo, rhs: ConnectionInfo) -> Bool {
        return lhs.otConnectionParticipant?.connectionId == rhs.otConnectionParticipant?.connectionId
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    var displayName: String {
        get {
            guard let otConnectionParticipant = otConnectionParticipant else {
                return displaySelf
            }
            return  otConnectionParticipant.connectionId
        }
    }
    
    func getOTConnection() -> OTConnection {
        guard let otConnectionParticipant = otConnectionParticipant else {
            return otConnectionHost
        }
        return otConnectionParticipant
    }
   
}

extension String {

    // only letters permitted are (A-Z and a-z), numbers (0-9), "-", "_", " " and "~".
    // hence we encode and decode with base64 to accomadate other characters like emojis etc.
    // Both sides needs to be part of this. This sample app will not use base64 encoding/decoding
    // and rely on the isValidSignal method below.
    
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
   // you could have used base64 encoding decoding here. But just for illustration ,
   // we assume the other  side is already deployed and we can't use base64.
    
    func isValidSignal() -> Bool {
        let m = self.count <= 128 && self.range(of: "[^a-zA-Z0-9-_~] ", options: .regularExpression) == nil
        return self.count <= 128 && self.range(of: "[^a-zA-Z0-9-_~] ", options: .regularExpression) == nil
    }
    func lastTenCharacter() -> String {
        return "..." + self.suffix(10)
    }
    
}

class VonageVideoSDK: NSObject {
    @Published var isSessionConnected = false
    @Published var connsInfo: [ConnectionInfo] = []
    @Published var messages: [SMessage] = []    //unlimited and last in , first out
    
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
        connsInfo.append(ConnectionInfo(otConnectionHost: session.connection!, otConnectionParticipant: nil))
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
      
    }
    
    func session(_ session: OTSession, connectionCreated connection: OTConnection) {
        connsInfo.append(ConnectionInfo(otConnectionHost: session.connection!, otConnectionParticipant: connection))
    }
    func session(_ session: OTSession, connectionDestroyed connection: OTConnection) {
        guard connsInfo.contains(connsInfo) else {
            return
        }
        let info = ConnectionInfo(otConnectionHost: session.connection!, otConnectionParticipant: connection)
        connsInfo = connsInfo.filter { $0 != info }
    }
    func session(_ session: OTSession, streamCreated stream: OTStream) {
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("Session Failed to connect: \(error.localizedDescription)")
    }
    
    func session(_ session: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        if let string = string, let type = type, let c = connection?.connectionId {
            let msg = SMessage(connId: c, type: type, content: string, outgoing: false)
            messages.insert(msg, at: 0)
            print("received data \(string) from \(connection?.connectionId ?? "")")
        }
    }
}

// MARK: - UI interface
extension VonageVideoSDK {
   
    func sendSignalToAll(type: String?, data: String?) {
        guard let type = type, let data = data , type.isValidSignal() == true && data.isValidSignal() == true else {
            return
        }
        session.signal(withType: type , string: data, connection:nil, error: nil)
        print("signal send")
    }
    
    func closeAll() {
        session.disconnect(nil)
    }
    
    func isMyConnection(_ connection: OTConnection) -> Bool {
        return session.connection?.connectionId == connection.connectionId
    }
    func sendSignalToConnection(connection: String, type: String?, data: String?, retryAfterConnect: Bool) {
        guard let type = type, let data = data ,
                  type.isValidSignal() == true && data.isValidSignal() == true else {
            return
        }
        for c in connsInfo where c.displayName == connection  {
            if retryAfterConnect == true {
                //retry is true by default
                session.signal(withType: type , string: data, connection:c.getOTConnection(), error: nil)
            } else {
                // You can use this call for all cases. We are just distinguishing here to show various way to call signal.
                session.signal(withType: type , string: data, connection:c.getOTConnection(), retryAfterReconnect: retryAfterConnect, error: nil)
            }

            print("signal send")
        }
    }
}

