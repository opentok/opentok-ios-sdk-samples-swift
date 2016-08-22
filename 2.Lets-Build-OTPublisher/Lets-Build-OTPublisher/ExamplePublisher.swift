//
//  ExamplePublisher.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import OpenTok

class ExamplePublisher: OTPublisher {    
    // Video capturer is not "retained" by the capturer so it is important
    // to save it as an instance variable
    var exampleCapturer: ExampleVideoCapture?
    var exampleRenderer: ExampleVideoRender?
    
    override init!(delegate: OTPublisherKitDelegate!, name: String!, audioTrack: Bool, videoTrack: Bool) {
        super.init(delegate: delegate, name: name, audioTrack: audioTrack, videoTrack: videoTrack)
    }
    override init!(delegate: OTPublisherKitDelegate!, name: String!) {
        super.init(delegate: delegate, name: name)
        exampleCapturer = ExampleVideoCapture()
        exampleRenderer = ExampleVideoRender()
        videoCapture = exampleCapturer!
        videoRender = exampleRenderer!
    }
    
    override var view: UIView! {
        get {
            return exampleRenderer
        }
    }
}