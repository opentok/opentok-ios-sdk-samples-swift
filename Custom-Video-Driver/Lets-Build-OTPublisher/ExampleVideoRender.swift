//
//  ExampleVideoRender.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import OpenTok
import GLKit

protocol ExampleVideoRenderDelegate {
    func renderer(_ renderer: ExampleVideoRender, didReceiveFrame videoFrame: OTVideoFrame)
}

class ExampleVideoRender: UIView {
    
    var delegate: ExampleVideoRenderDelegate?
    var mirroring: Bool = true {
        didSet {
            if let renderer = renderer {
                renderer.mirroring = mirroring
            }
        }
    }
    
    fileprivate var glContext: EAGLContext?
    fileprivate var renderer: EAGLVideoRenderer?
    fileprivate var glkView: GLKView?
    fileprivate var frameLock: NSLock?
    fileprivate var renderingEnabled: Bool = true
    fileprivate var lastVideoFrame: OTVideoFrame?
    fileprivate var displayLinkProxy: DisplayLinkProxy?
    fileprivate var displayLink: CADisplayLink?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        glContext = EAGLContext(api:.openGLES2)
        renderer = EAGLVideoRenderer(context: glContext!)
       
        glkView = GLKView(frame: CGRect.zero, context: glContext!)
        glkView?.drawableColorFormat = .RGBA8888
        glkView?.drawableDepthFormat = .formatNone
        glkView?.drawableStencilFormat = .formatNone
        glkView?.drawableMultisample = .multisampleNone
        glkView?.delegate = self;
        glkView?.layer.masksToBounds = true;
        addSubview(glkView!)
        
        frameLock = NSLock()
        
        NotificationCenter.default
            .addObserver(self, selector: #selector(ExampleVideoRender.willResignActive),
                         name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default
            .addObserver(self, selector: #selector(ExampleVideoRender.didBecomeActive),
                         name: UIApplication.didBecomeActiveNotification, object: nil)
        
        
        displayLinkProxy = DisplayLinkProxy(glkView: glkView!, videoRender: self)
        displayLink = CADisplayLink(target: displayLinkProxy!, selector:#selector(DisplayLinkProxy.displayLinkDidFire(_:)))
        
        if #available(iOS 10, *) {
            displayLink!.preferredFramesPerSecond = 30
        }
        
        displayLink!.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
        
        renderer!.mirroring = mirroring
        renderer!.setupGL()
        
        displayLink!.isPaused = false
    }
    
    @objc func willResignActive() {
        displayLink!.isPaused = true
        glkView?.deleteDrawable()
        renderer!.teardownGL()
    }
    
    @objc func didBecomeActive() {
        renderer!.setupGL()
        displayLink!.isPaused = false
    }
    
    var needsRendererUpdate: Bool {
        get {
            guard lastVideoFrame != nil else {
                return false
            }
            return renderer?.lastFrameTime != lastVideoFrame?.timestamp.value
        }
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        glkView?.frame = bounds
    }
    
    fileprivate func calculatePlaneSize(forFrame frame: OTVideoFrame)
        -> (ySize: Int, uSize: Int, vSize: Int)
    {
        guard let frameFormat = frame.format
            else {
                return (0, 0 ,0)
        }
        let baseSize = Int(frameFormat.imageWidth * frameFormat.imageHeight) * MemoryLayout<GLubyte>.size
        return (baseSize, baseSize / 4, baseSize / 4)
    }
}

extension ExampleVideoRender: GLKViewDelegate {
    
    func glkView(_ view: GLKView, drawIn rect: CGRect) {
        defer {
            frameLock?.unlock()
        }
        frameLock?.lock()
        //Coming from bg you will double render and deallocate will crash below. Hence check for lastVideoFrameRendered == false
        guard let lastVideoFrame = lastVideoFrame
            else {
                return
        }
        
        renderer?.drawFrame(frame: lastVideoFrame, withViewport: view.frame)
        deallocateFrame(lastVideoFrame)
        self.lastVideoFrame = nil
    }
    
    func deallocateFrame(_ frame: OTVideoFrame?) -> Void {
        guard let frame = frame else {
            return
        }
        
        let yPlane: UnsafeMutablePointer<GLubyte>? = frame.planes?.pointer(at: 0)?.assumingMemoryBound(to: GLubyte.self)
        let uPlane: UnsafeMutablePointer<GLubyte>? = frame.planes?.pointer(at: 1)?.assumingMemoryBound(to: GLubyte.self)
        let vPlane: UnsafeMutablePointer<GLubyte>? = frame.planes?.pointer(at: 2)?.assumingMemoryBound(to: GLubyte.self)
        
        yPlane?.deallocate()
        uPlane?.deallocate()
        vPlane?.deallocate()

    }
    
}

extension ExampleVideoRender: OTVideoRender {
    func renderVideoFrame(_ frame: OTVideoFrame) {
        if let fLock = frameLock, let format = frame.format {
            fLock.lock()
            assert(format.pixelFormat == .I420)

            deallocateFrame(lastVideoFrame)
            
            lastVideoFrame = OTVideoFrame(format: format)
            lastVideoFrame?.timestamp = frame.timestamp
            
            let planeSize = calculatePlaneSize(forFrame: frame)
            let yPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.ySize)
            let uPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.uSize)
            let vPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.vSize)
            
            memcpy(yPlane, frame.planes?.pointer(at: 0), planeSize.ySize)
            memcpy(uPlane, frame.planes?.pointer(at: 1), planeSize.uSize)
            memcpy(vPlane, frame.planes?.pointer(at: 2), planeSize.vSize)
            
            lastVideoFrame?.planes?.addPointer(yPlane)
            lastVideoFrame?.planes?.addPointer(uPlane)
            lastVideoFrame?.planes?.addPointer(vPlane)
    
            fLock.unlock()
            
            if let delegate = delegate {
                delegate.renderer(self, didReceiveFrame: frame)
            }
        }
    }
}


class DisplayLinkProxy {
    var renderer: ExampleVideoRender
    var view: GLKView
    
    init(glkView: GLKView, videoRender: ExampleVideoRender) {
        renderer = videoRender
        view = glkView
    }
    
    @objc func displayLinkDidFire(_ displayLink: CADisplayLink) {
        if renderer.needsRendererUpdate {
            view.setNeedsDisplay()
        }
    }
}
