//
//  ExampleVideoCapture.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import OpenTok
import AVFoundation

extension UIApplication {
    func currentDeviceOrientation(cameraPosition pos: AVCaptureDevicePosition) -> OTVideoOrientation {
        let orientation = statusBarOrientation
        if pos == .front {
            switch orientation {
            case .landscapeLeft: return .up
            case .landscapeRight: return .down
            case .portrait: return .left
            case .portraitUpsideDown: return .right
            case .unknown: return .up
            }
        } else {
            switch orientation {
            case .landscapeLeft: return .down
            case .landscapeRight: return .up
            case .portrait: return .left
            case .portraitUpsideDown: return .right
            case .unknown: return .up
            }
        }
    }
}

extension String {
    func dimensionForCapturePreset() -> (width: UInt32, height: UInt32) {
        switch self {
        case AVCaptureSessionPreset352x288: return (352, 288)
        case AVCaptureSessionPreset640x480, AVCaptureSessionPresetHigh: return (640, 480)
        case AVCaptureSessionPresetLow: return (192, 144)
        case AVCaptureSessionPresetMedium: return (480, 360)
        case AVCaptureSessionPreset1280x720: return (1280, 720)
        default: return (352, 288)
        }
    }
}

class ExampleVideoCapture: OTVideoCaptureSwift30Proxy {    
    var captureSession: AVCaptureSession?
    var videoInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureVideoDataOutput?
    
    fileprivate var capturePreset: String {
        didSet {
            (captureWidth, captureHeight) = capturePreset.dimensionForCapturePreset()
        }
    }
    
    fileprivate var captureWidth: UInt32
    fileprivate var captureHeight: UInt32
    fileprivate var capturing = false
    fileprivate let videoFrame: OTVideoFrame
    
    let captureQueue: DispatchQueue
    
    override init() {
        capturePreset = AVCaptureSessionPresetMedium
        captureQueue = DispatchQueue(label: "com.tokbox.VideoCapture", attributes: [])
        (captureWidth, captureHeight) = capturePreset.dimensionForCapturePreset()
        videoFrame = OTVideoFrame(format: OTVideoFormat.init(nv12WithWidth: captureWidth, height: captureHeight))
    }
    
    // MARK: - AVFoundation functions
    fileprivate func setupAudioVideoSession() throws {
        captureSession = AVCaptureSession()
        captureSession?.beginConfiguration()

        captureSession?.sessionPreset = capturePreset
        captureSession?.usesApplicationAudioSession = false

        // Configure Camera Input
        guard let device = camera(withPosition: .front)
            else {
                print("Failed to acquire camera device for video")
                return
        }

        videoInput = try AVCaptureDeviceInput(device: device)
        captureSession?.addInput(videoInput)
        
        // Configure Ouput
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        videoOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
        videoOutput?.setSampleBufferDelegate(self, queue: captureQueue)
        
        captureSession?.addOutput(videoOutput)
        setFrameRate()
        captureSession?.commitConfiguration()
        
        captureSession?.startRunning()
    }
    
    fileprivate func frameRateRange(forFrameRate fps: Int) -> AVFrameRateRange? {
        return videoInput?.device.activeFormat.videoSupportedFrameRateRanges.filter({ range in
            guard let range = range as? AVFrameRateRange
                else {
                    return false
            }
            return range.minFrameRate <= Double(fps) && Double(fps) <= range.maxFrameRate
        }).first as? AVFrameRateRange
    }
    
    fileprivate func setFrameRate(fps: Int = 20) {
        guard let _ = frameRateRange(forFrameRate: fps)
            else {
                print("Unsupported frameRate \(fps)")
                return
        }
        
        let desiredMinFps = CMTime(value: 1, timescale: CMTimeScale(fps))
        let desiredMaxFps = CMTime(value: 1, timescale: CMTimeScale(fps))
        
        do {
            try videoInput?.device.lockForConfiguration()
            videoInput?.device.activeVideoMinFrameDuration = desiredMinFps
            videoInput?.device.activeVideoMaxFrameDuration = desiredMaxFps
        } catch {
            print("Error setting framerate")
        }
        
    }
    
    fileprivate func camera(withPosition pos: AVCaptureDevicePosition) -> AVCaptureDevice? {
        return AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo).filter({ ($0 as! AVCaptureDevice).position == pos }).first as? AVCaptureDevice
    }
    
    fileprivate func updateCaptureFormat(width w: UInt32, height h: UInt32) {
        captureWidth = w
        captureHeight = h
        videoFrame.format = OTVideoFormat.init(nv12WithWidth: w, height: h)
    }

    // MARK: - OTVideoCapture protocol
    override func proxyInit() {
        captureQueue.async {
            do {
                try self.setupAudioVideoSession()
            } catch let error as NSError {
                print("Error configuring AV Session: \(error)")
            }
        }
    }
    
    override func proxyStart() -> Int32 {
        capturing = true
        self.captureSession?.startRunning()
        return 0
    }
    
    override func proxyStop() -> Int32 {
        capturing = false
        return 0
    }
    
    override func proxyRelease() {
        let _ = stop()
        videoOutput?.setSampleBufferDelegate(nil, queue: captureQueue)
        captureQueue.sync {
            self.captureSession?.stopRunning()
        }
        captureSession = nil
        videoOutput = nil
        videoInput = nil

    }
    
    override func proxyIsStarted() -> Bool {
        return capturing && (captureSession != nil)
    }
    
    override func proxySettings(_ videoFormat: OTVideoFormat!) -> Int32 {
        videoFormat.pixelFormat = .NV12
        videoFormat.imageWidth = captureWidth
        videoFormat.imageHeight = captureHeight
        return 0
    }
}

extension ExampleVideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("Dropping frame")
    }        
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if !capturing || videoCaptureConsumer == nil {
            return
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else {
                print("Error acquiring sample buffer")
                return
        }
        
        guard let videoInput = videoInput
            else {
                print("Capturer does not have a valid input")
                return
        }
        
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        videoFrame.timestamp = time
        let height = UInt32(CVPixelBufferGetHeight(imageBuffer))
        let width = UInt32(CVPixelBufferGetWidth(imageBuffer))
        
        if width != captureWidth || height != captureHeight {
            updateCaptureFormat(width: width, height: height)
        }
        
        videoFrame.format.imageWidth = width
        videoFrame.format.imageHeight = height
        let minFrameDuration = videoInput.device.activeVideoMinFrameDuration
        
        videoFrame.format.estimatedFramesPerSecond = Double(minFrameDuration.timescale) / Double(minFrameDuration.value)
        videoFrame.format.estimatedCaptureDelay = 100
        videoFrame.orientation = UIApplication.shared
            .currentDeviceOrientation(cameraPosition: videoInput.device.position)
        
        videoFrame.clearPlanes()
        
        if !CVPixelBufferIsPlanar(imageBuffer) {
            videoFrame.planes?.addPointer(CVPixelBufferGetBaseAddress(imageBuffer))
        } else {
            for idx in 0..<CVPixelBufferGetPlaneCount(imageBuffer) {
                videoFrame.planes?.addPointer(CVPixelBufferGetBaseAddressOfPlane(imageBuffer, idx))
            }
        }
        
        videoCaptureConsumer.consumeFrame(videoFrame)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
    }
}
