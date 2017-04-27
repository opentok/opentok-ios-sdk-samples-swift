//
//  ExamplePublisher.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import OpenTok

class ExamplePublisher: OTPublisherKit {
    // Video capturer is not "retained" by the capturer so it is important
    // to save it as an instance variable
    var exampleCapturer: ExampleVideoCapture?
    var exampleRenderer: ExampleVideoRender?
    
    override init?(delegate: OTPublisherKitDelegate!, name: String!, audioTrack: Bool, videoTrack: Bool) {
        let settings = OTPublisherSettings()
        settings.name = name
        settings.videoTrack = videoTrack
        settings.audioTrack = audioTrack
        super.init(delegate: delegate, settings: settings)
    }
    override init?(delegate: OTPublisherKitDelegate!, name: String!) {
        let settings = OTPublisherSettings()
        settings.name = name
        super.init(delegate: delegate, settings: settings)
        exampleCapturer = ExampleVideoCapture()
        exampleRenderer = ExampleVideoRender()
        videoCapture = exampleCapturer!
        videoRender = exampleRenderer!
    }
    
    var view: UIView {
        get {
            return exampleRenderer!
        }
    }
}
