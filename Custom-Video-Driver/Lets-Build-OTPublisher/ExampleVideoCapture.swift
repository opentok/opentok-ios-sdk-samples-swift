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

class ExampleVideoCapture: NSObject, OTVideoCapture {
    var captureSession: AVCaptureSession?
    var videoInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureVideoDataOutput?
    
    var videoCaptureConsumer: OTVideoCaptureConsumer?
    
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
        capturePreset = AVCaptureSessionPreset640x480
        captureQueue = DispatchQueue(label: "com.tokbox.VideoCapture", attributes: [])
        (captureWidth, captureHeight) = capturePreset.dimensionForCapturePreset()
        videoFrame = OTVideoFrame(format: OTVideoFormat(nv12WithWidth: captureWidth, height: captureHeight))
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
    func initCapture() {
        captureQueue.async {
            do {
                try self.setupAudioVideoSession()
            } catch let error as NSError {
                print("Error configuring AV Session: \(error)")
            }
        }
    }
    
    func start() -> Int32 {
        capturing = true
        self.captureSession?.startRunning()
        return 0
    }
    
    func stop() -> Int32 {
        capturing = false
        return 0
    }
    
    func releaseCapture() {
        let _ = stop()
        videoOutput?.setSampleBufferDelegate(nil, queue: captureQueue)
        captureQueue.sync {
            self.captureSession?.stopRunning()
        }
        captureSession = nil
        videoOutput = nil
        videoInput = nil

    }
    
    func isCaptureStarted() -> Bool {
        return capturing && (captureSession != nil)
    }
    
    func captureSettings(_ videoFormat: OTVideoFormat) -> Int32 {
        videoFormat.pixelFormat = .NV12
        videoFormat.imageWidth = captureWidth
        videoFormat.imageHeight = captureHeight
        return 0
    }
    
    fileprivate func frontFacingCamera() -> AVCaptureDevice? {
        return camera(withPosition: .front)
    }
    
    fileprivate func backFacingCamera() -> AVCaptureDevice? {
        return camera(withPosition: .back)
    }
    
    fileprivate var hasMultipleCameras : Bool {
        return AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo).count > 1
    }
    
    func setCameraPosition(_ position: AVCaptureDevicePosition) -> Bool {
        guard let preset = captureSession?.sessionPreset else {
            return false
        }
        
        let newVideoInput: AVCaptureDeviceInput? = {
            do {
                if position == AVCaptureDevicePosition.back {
                    return try AVCaptureDeviceInput.init(device: backFacingCamera())
                } else if position == AVCaptureDevicePosition.front {
                    return try AVCaptureDeviceInput.init(device: frontFacingCamera())
                } else {
                    return nil
                }
            } catch {
                return nil
            }
        }()
        
        guard let newInput = newVideoInput else {
            return false
        }
        
        var success = true
        
        captureQueue.sync {
            captureSession?.beginConfiguration()
            captureSession?.removeInput(videoInput)
            
            if captureSession?.canAddInput(newInput) ?? false {
                captureSession?.addInput(newInput)
                videoInput = newInput
            } else {
                success = false
                captureSession?.addInput(videoInput)
            }
            
            captureSession?.commitConfiguration()
        }
        
        if success {
            capturePreset = preset
        }
        
        return success
    }
    
    func toggleCameraPosition() -> Bool {
        guard hasMultipleCameras else {
            return false
        }
        
        if  videoInput?.device.position == .front {
            return setCameraPosition(.back)
        } else {
            return setCameraPosition(.front)
        }
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
        
        videoFrame.format?.imageWidth = width
        videoFrame.format?.imageHeight = height
        let minFrameDuration = videoInput.device.activeVideoMinFrameDuration
        
        videoFrame.format?.estimatedFramesPerSecond = Double(minFrameDuration.timescale) / Double(minFrameDuration.value)
        videoFrame.format?.estimatedCaptureDelay = 100
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
        
        videoCaptureConsumer!.consumeFrame(videoFrame)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
    }
}
