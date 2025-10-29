//
//  CustomVideoRender.swift
//  Basic-Video-Renderer
//
//  Created by Artur Osiński on 27/10/2025.
//  Copyright © 2025 Vonage. All rights reserved.
//

import OpenTok

class CustomVideoRender: NSObject, OTVideoRender {
    
    var renderView: UIView

    override init() {
        // Initialize with your custom render view
        self.renderView = CustomRenderView(frame: .zero)
        super.init()
    }
    
    func renderVideoFrame(_ frame: OTVideoFrame) {
        // Cast to your custom view type and pass the frame for rendering
        (renderView as? CustomRenderView)?.renderVideoFrame(frame)
    }
}
