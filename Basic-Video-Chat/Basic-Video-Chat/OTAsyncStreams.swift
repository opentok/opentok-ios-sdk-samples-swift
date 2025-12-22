//
//  OTAsyncStreams.swift
//  Basic-Video-Chat
//
//  Created by Jaideep Shah on 9/10/24.
//  Copyright © 2024 tokbox. All rights reserved.
//


import Foundation
import OpenTok

// Define a class that will provide the AsyncStream
class OTSessionManager: NSObject, OTSessionDelegate {
    
    private let streamContinuation: AsyncStream<OTStream>.Continuation
    private var session: OTSession?
    
    init(streamContinuation: AsyncStream<OTStream>.Continuation) {
        self.streamContinuation = streamContinuation
        super.init()
    }
    
    func startSession(_ session: OTSession) {
        self.session = session
        self.session?.delegate = self
    }
    
    func sessionDidConnect(_ session: OTSession) {
        
    }
    func sessionDidDisconnect(_ session: OTSession) {
        
    }
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        
    }
    func session(_ session: OTSession, didFailWithError error: OTError) {
        
    }
    // Objective-C callback for stream creation
    func session(_ mySession: OTSession, streamCreated stream: OTStream) {
        // Yield the OTStream to the AsyncStream
        streamContinuation.yield(stream)
    }
    
    // Method to finish the AsyncStream
    func finishStream() {
        streamContinuation.finish()
    }
}

// Function to create an AsyncStream of OTStream
func otStreamAsyncStream() -> AsyncStream<OTStream> {
    AsyncStream { continuation in
        let manager = OTSessionManager(streamContinuation: continuation)
        
        // Assuming you have a way to start the session, e.g., with a session object
        // manager.startSession(yourSessionObject)
        
        // Return the manager, which will handle the lifecycle of the session
        // and provide streams
    }
}

// Test
//Task {
//    let asyncStream = otStreamAsyncStream()
//    
//    for await stream in asyncStream {
//        // Handle the OTStream objects here
//        print("Received OTStream: \(stream)")
//    }
//}
