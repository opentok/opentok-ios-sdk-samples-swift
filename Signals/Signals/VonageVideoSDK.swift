//
//  VonageVideoSDK.swift
//  Signals
//
//  Created by Jaideep Shah on 2/15/23.
//

import UIKit
import OpenTok



let kApiKey = ""
// Replace with your generated session ID
let kSessionId = ""
// Replace with your generated token
let kToken = ""

class VonageVideoSDK: NSObject {
    @Published var isSessionConnected = false
    @Published var connsInfo: [ConnectionInfo] = []
    @Published var messages: [SignalMessage] = []    //unlimited and last in , first out

    lazy var session: OTSession = {
        //make sure you have entered the credentials above , else you get an exception here
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
        connsInfo.append(ConnectionInfo(otMyConnection: session.connection!, otParticipantConnection: nil))
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
      
    }
    
    func session(_ session: OTSession, connectionCreated connection: OTConnection) {
        connsInfo.append(ConnectionInfo(otMyConnection: session.connection!, otParticipantConnection: connection))
    }
    func session(_ session: OTSession, connectionDestroyed connection: OTConnection) {
        guard connsInfo.contains(connsInfo) else {
            return
        }
        let info = ConnectionInfo(otMyConnection: session.connection!, otParticipantConnection: connection)
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
            addMessage(connection: c, type: type, data: string, outgoing: false)
        }
    }
}

// MARK: - UI interface
extension VonageVideoSDK {
    private func addMessage(connection: String?, type: String, data: String, outgoing: Bool) {
        messages.insert(SignalMessage(connId: connection, type: type, content: data, outgoing: outgoing), at: 0)
    }
    
    func sendSignalToAll(type: String?, data: String?) {
        guard let type = type, let data = data , type.isValidSignal() == true && data.isValidSignal() == true else {
            return
        }
        session.signal(withType: type , string: data, connection:nil, error: nil)
        addMessage(connection: nil, type: type, data: data, outgoing: true)
    }
    
    func closeAll() {
        session.disconnect(nil)
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
            addMessage(connection: c.displayName, type: type, data: data, outgoing: true)
        }
    }
}

struct SignalMessage: Identifiable {
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
    var otMyConnection : OTConnection
    var otParticipantConnection : OTConnection?
    let displaySelf = "Self"
    
    static func ==(lhs: ConnectionInfo, rhs: ConnectionInfo) -> Bool {
        return lhs.otParticipantConnection?.connectionId == rhs.otParticipantConnection?.connectionId
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    var displayName: String {
        get {
            guard let otConnectionParticipant = otParticipantConnection else {
                return displaySelf
            }
            return  otConnectionParticipant.connectionId
        }
    }
    
    func getOTConnection() -> OTConnection {
        guard let otConnectionParticipant = otParticipantConnection else {
            return otMyConnection
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
        return self.count <= 128 && self.range(of: "[^a-zA-Z0-9-_~\\s]", options: .regularExpression) == nil
    }
    func lastTenCharacter() -> String {
        return "..." + self.suffix(10)
    }
    
}
