//
//  SampleBufferVideoCallView.swift
//  Picture-In-Picture
//
//  Created by iujie on 10/05/2024.
//  Copyright © 2024 tokbox. All rights reserved.
//

import UIKit
import AVKit

class SampleBufferVideoCallView: UIView {
    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }
}

