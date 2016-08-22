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
    func renderer(renderer: ExampleVideoRender, didReceiveFrame: OTVideoFrame)
}

class ExampleVideoRender: UIView {
    private var glContext: EAGLContext?
    private var renderer: EAGLVideoRenderer?
    private var glkView: GLKView?
    
    private var frameLock: NSLock?
    
    private var renderingEnabled: Bool = true
    private var clearRenderer = 0
    
    private var lastVideoFrame: OTVideoFrame?
    
    private var displayLinkProxy: DisplayLinkProxy?
    private var displayLink: CADisplayLink?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        glContext = EAGLContext(API:.OpenGLES2)
        renderer = EAGLVideoRenderer(context: glContext!)
        glkView = GLKView(frame: CGRectZero, context: glContext!)
        
        glkView?.drawableColorFormat = .RGBA8888
        glkView?.drawableDepthFormat = .FormatNone
        glkView?.drawableStencilFormat = .FormatNone
        glkView?.drawableMultisample = .MultisampleNone
        glkView?.delegate = self;
        glkView?.layer.masksToBounds = true;
        
        addSubview(glkView!)
        
        frameLock = NSLock()
        
        NSNotificationCenter.defaultCenter()
            .addObserver(self, selector: #selector(ExampleVideoRender.willResignActive),
                         name: UIApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter()
            .addObserver(self, selector: #selector(ExampleVideoRender.didBecomeActive),
                         name: UIApplicationDidBecomeActiveNotification, object: nil)
        
        
        displayLinkProxy = DisplayLinkProxy(glkView: glkView!, videoRender: self)
        displayLink = CADisplayLink(target: displayLinkProxy!, selector:#selector(DisplayLinkProxy.displayLinkDidFire(_:)))
        displayLink!.frameInterval = 2
        displayLink!.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        
        renderer!.setupGL()
        
        displayLink!.paused = false
    }
    
    func willResignActive() {
        displayLink!.paused = true
        glkView?.deleteDrawable()
        renderer!.teardownGL()
    }
    
    func didBecomeActive() {
        renderer!.setupGL()
        displayLink!.paused = false
    }
    
    var needsRendererUpdate: Bool {
        get {
            return renderer?.lastFrameTime != lastVideoFrame?.timestamp.value
                || clearRenderer != 0
        }
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        glkView?.frame = bounds
    }
    
    private func calculatePlaneSize(forFrame frame: OTVideoFrame)
        -> (ySize: Int, uSize: Int, vSize: Int)
    {
        let baseSize = Int(frame.format.imageWidth * frame.format.imageHeight) * sizeof(GLubyte)
        return (baseSize, baseSize / 4, baseSize / 4)
    }
}

extension ExampleVideoRender: GLKViewDelegate {
    
    func glkView(view: GLKView, drawInRect rect: CGRect) {
        defer {
            frameLock?.unlock()
        }
        frameLock?.lock()
        guard let frame = lastVideoFrame
            else {
                return
        }
        
        renderer?.drawFrame(frame: frame, withViewport: view.frame)
        
        let yPlane = UnsafeMutablePointer<GLubyte>(frame.planes.pointerAtIndex(0))
        let uPlane = UnsafeMutablePointer<GLubyte>(frame.planes.pointerAtIndex(1))
        let vPlane = UnsafeMutablePointer<GLubyte>(frame.planes.pointerAtIndex(2))
        let planeSize = calculatePlaneSize(forFrame: frame)
        yPlane.dealloc(planeSize.ySize)
        uPlane.dealloc(planeSize.uSize)
        vPlane.dealloc(planeSize.vSize)
    }
    
}

extension ExampleVideoRender: OTVideoRender {
    func renderVideoFrame(frame: OTVideoFrame!) {
        frameLock?.lock()
        assert(frame.format.pixelFormat == .I420)
        
        lastVideoFrame = OTVideoFrame(format: frame.format)
        lastVideoFrame?.timestamp = frame.timestamp
        
        let planeSize = calculatePlaneSize(forFrame: frame)
        let yPlane = UnsafeMutablePointer<GLubyte>.alloc(planeSize.ySize)
        let uPlane = UnsafeMutablePointer<GLubyte>.alloc(planeSize.uSize)
        let vPlane = UnsafeMutablePointer<GLubyte>.alloc(planeSize.vSize)
        
        memcpy(yPlane, frame.planes.pointerAtIndex(0), planeSize.ySize)
        memcpy(uPlane, frame.planes.pointerAtIndex(1), planeSize.uSize)
        memcpy(vPlane, frame.planes.pointerAtIndex(2), planeSize.vSize)
        
        lastVideoFrame?.planes.addPointer(yPlane)
        lastVideoFrame?.planes.addPointer(uPlane)
        lastVideoFrame?.planes.addPointer(vPlane)
        
        frameLock?.unlock()        
    }
}


class DisplayLinkProxy {
    var renderer: ExampleVideoRender
    var view: GLKView
    
    init(glkView: GLKView, videoRender: ExampleVideoRender) {
        renderer = videoRender
        view = glkView
    }
    
    @objc func displayLinkDidFire(displayLink: CADisplayLink) {
        if renderer.needsRendererUpdate {
            view.setNeedsDisplay()
        }
    }
}