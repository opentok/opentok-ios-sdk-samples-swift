//
//  OTCombine.swift
//  Basic-Video-Chat
//
//  Created by Jaideep Shah on 8/21/24.
//  Copyright © 2024 tokbox. All rights reserved.
//

import Foundation
import OpenTok
import Combine

class OTSwPublisher: OTPublisher, OTPublisherKitNetworkStatsDelegate {
    var namePublisher: Just<String> = Just("")
    var subject = PassthroughSubject<[OTPublisherKitVideoNetworkStats], Never>()
    
    override init?(delegate: (any OTPublisherKitDelegate)?) {
        super.init(delegate: delegate)
        self.namePublisher =  Just(self.name ?? "" )
    }
    
    override init?(delegate: (any OTPublisherKitDelegate)?, settings: OTPublisherSettings) {
        super.init(delegate: delegate, settings: settings)
        self.namePublisher =  Just(self.name ?? "")
    }
    
    func setupNetworkStatsDelegate() {
        //TODO: make a combine specific delegate in ObjC , so as to not conflict
        self.networkStatsDelegate = self
    }
    
    func stopNetworkStatsDelegate() {
        self.networkStatsDelegate = nil
        subject.send(completion: .finished)
    }
    
    // Method to emit values via the subject
    private func emitValue(_ stats: [OTPublisherKitVideoNetworkStats]) {
        subject.send(stats)
    }

    func publisher(_ publisher: OTPublisherKit, videoNetworkStatsUpdated stats: [OTPublisherKitVideoNetworkStats]) {
        emitValue(stats)
    }

}

/*
 import Combine

 class GenericDelegateHandler<T>: NSObject {
     // Generic PassthroughSubject for any type T
     var subject = PassthroughSubject<T, Never>()
     
     // Initializer
     init(publisher: AnyObject, setup: (AnyObject, GenericDelegateHandler<T>) -> Void) {
         super.init()
         setup(publisher, self)
     }
     
     // Method to emit values via the subject
     func emitValue(_ value: T) {
         subject.send(value)
     }
     
     // Method to stop the subject
     func stop() {
         subject.send(completion: .finished)
     }
 }

 import Combine

 // Define your specific type
 typealias VideoNetworkStatsHandler = GenericDelegateHandler<[OTPublisherKitVideoNetworkStats]>

 // Usage with OTPublisherKit
 let videoNetworkStatsHandler = VideoNetworkStatsHandler(publisher: publisher) { publisher, handler in
     guard let publisher = publisher as? OTPublisherKit else { return }
     publisher.delegate = handler
 }

 // Implementing the delegate method
 extension VideoNetworkStatsHandler: OTPublisherKitDelegate {
     func publisher(_ publisher: OTPublisherKit, videoNetworkStatsUpdated stats: [OTPublisherKitVideoNetworkStats]) {
         // Send the stats via the subject when the delegate method is called
         emitValue(stats)
     }
 }

 // Subscription example
 let subscription = videoNetworkStatsHandler.subject.sink { statsArray in
     for stat in statsArray {
         print("bytesSend: \(stat.bytesSend)")
     }
 }

 typealias AnotherHandler = GenericDelegateHandler<YourDataType>

 // Implement the corresponding delegate method
 extension AnotherHandler: YourDelegateType {
     func yourDelegateMethod(data: YourDataType) {
         emitValue(data)
     }
 }

 */
