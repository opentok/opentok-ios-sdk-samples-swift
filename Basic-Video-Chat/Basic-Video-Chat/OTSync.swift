//
//  OTSync.swift
//  Basic-Video-Chat
//
//  Created by Jaideep Shah on 8/30/24.
//  Copyright © 2024 tokbox. All rights reserved.
//



import Foundation
import OpenTok

import Foundation
import ObjectiveC

extension OTPublisherKit {

    // Define the unique key for associated objects
    private static var associatedObjectHandle: UInt8 = 0

    // Method to set the associated object (e.g., wrapper)
    private func setAssociatedWrapper(_ wrapper: PublisherKitDelegateWrapper?) {
        objc_setAssociatedObject(self, &Self.associatedObjectHandle, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // Method to get the associated object
    private func associatedWrapper() -> PublisherKitDelegateWrapper? {
        return objc_getAssociatedObject(self, &Self.associatedObjectHandle) as? PublisherKitDelegateWrapper
    }
}


extension OTPublisherKit {

    // Internal wrapper class to handle the Objective-C callbacks
    private class PublisherKitDelegateWrapper: NSObject, OTPublisherDelegate {
        let continuation: CheckedContinuation<OTStream, Error>

        init(continuation: CheckedContinuation<OTStream, Error>) {
            self.continuation = continuation
        }

        func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
                print("Wrapper Publishing")
                continuation.resume(returning: stream)
        }
        
        func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
                print("Wrapper Publishing stream destroyed")
                continuation.resume(returning: stream)
        }

        func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
            print("Wrapper Publisher failed: \(error.localizedDescription)")
            continuation.resume(throwing: error)
        }
    }
    
    // Async function to wait for a stream to be created
    func waitForStreamCreated() async throws -> OTStream {
        try await withCheckedThrowingContinuation { continuation in
            let wrapper = PublisherKitDelegateWrapper(continuation: continuation)
            setAssociatedWrapper(wrapper)
            self.delegate = wrapper
        }
    }

    // Async function to wait for a stream to be destroyed
    func waitForStreamDestroyed() async throws -> OTStream {
        try await withCheckedThrowingContinuation { continuation in
            let wrapper = PublisherKitDelegateWrapper(continuation: continuation)
            self.delegate = wrapper
            setAssociatedWrapper(nil)
        }
    }
}
