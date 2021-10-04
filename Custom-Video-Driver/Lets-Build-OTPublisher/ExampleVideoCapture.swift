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
    func currentDeviceOrientation(cameraPosition pos: AVCaptureDevice.Position) -> OTVideoOrientation {
        let orientation = statusBarOrientation
        if pos == .front {
            switch orientation {
            case .landscapeLeft: return .up
            case .landscapeRight: return .down
            case .portrait: return .left
            case .portraitUpsideDown: return .right
            case .unknown: return .up
            @unknown default: fatalError()
            }
        } else {
            switch orientation {
            case .landscapeLeft: return .down
            case .landscapeRight: return .up
            case .portrait: return .left
            case .portraitUpsideDown: return .right
            case .unknown: return .up
            @unknown default: fatalError()
            }
        }
    }
}

extension AVCaptureSession.Preset {
    func dimensionForCapturePreset() -> (width: UInt32, height: UInt32) {
        switch self {
        case AVCaptureSession.Preset.cif352x288: return (352, 288)
        case AVCaptureSession.Preset.vga640x480, AVCaptureSession.Preset.high: return (640, 480)
        case AVCaptureSession.Preset.low: return (192, 144)
        case AVCaptureSession.Preset.medium: return (480, 360)
        case AVCaptureSession.Preset.hd1280x720: return (1280, 720)
        default: return (352, 288)
        }
    }
}

protocol FrameCapturerMetadataDelegate {
    func finishPreparingFrame(_ videoFrame: OTVideoFrame?)
}

class ExampleVideoCapture: NSObject, OTVideoCapture {
    var videoContentHint: OTVideoContentHint
    var captureSession: AVCaptureSession?
    var videoInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureVideoDataOutput?
    
    var videoCaptureConsumer: OTVideoCaptureConsumer?
    
    var delegate: FrameCapturerMetadataDelegate?
    
    var cameraPosition: AVCaptureDevice.Position {
        get {
            return videoInput?.device.position ?? .unspecified
        }
    }
    
    fileprivate var capturePreset: AVCaptureSession.Preset {
        didSet {
            (captureWidth, captureHeight) = capturePreset.dimensionForCapturePreset()
        }
    }
    
    fileprivate var captureWidth: UInt32
    fileprivate var captureHeight: UInt32
    fileprivate var capturing = false
    fileprivate let videoFrame: OTVideoFrame
    fileprivate var videoFrameOrientation: OTVideoOrientation = .left  //potrait
    
    let captureQueue: DispatchQueue
    
    fileprivate func updateFrameOrientation() {
        DispatchQueue.main.async {
            guard let inputDevice = self.videoInput else {
                return;
            }
            self.videoFrameOrientation = UIApplication.shared.currentDeviceOrientation(cameraPosition: inputDevice.device.position)
        }
    }
    
    override init() {
        self.videoContentHint = .none
        capturePreset = AVCaptureSession.Preset.vga640x480
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
        guard let videoInput = self.videoInput else {
            print("There was an error creating videoInput")
            return
        }
        captureSession?.addInput(videoInput)
        
        // Configure Ouput
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        videoOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
        videoOutput?.setSampleBufferDelegate(self, queue: captureQueue)
        
        guard let videoOutput = self.videoOutput else {
            print("There was an error creating videoOutput")
            return
        }
        captureSession?.addOutput(videoOutput)
        setFrameRate()
        captureSession?.commitConfiguration()
        
        captureSession?.startRunning()
    }
    
    fileprivate func frameRateRange(forFrameRate fps: Int) -> AVFrameRateRange? {
        return videoInput?.device.activeFormat.videoSupportedFrameRateRanges.filter({ range in
            return range.minFrameRate <= Double(fps) && Double(fps) <= range.maxFrameRate
        }).first
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
    
    fileprivate func camera(withPosition pos: AVCaptureDevice.Position) -> AVCaptureDevice? {
        guard #available(iOS 10, *) else { return nil }
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: pos).devices.first
    }
    
    fileprivate func updateCaptureFormat(width w: UInt32, height h: UInt32) {
        captureWidth = w
        captureHeight = h
        videoFrame.format = OTVideoFormat.init(nv12WithWidth: w, height: h)
    }

    // MARK: - OTVideoCapture protocol
    func initCapture() {
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                               object: nil,
                                               queue: .main,
                                               using: { (_) in self.updateFrameOrientation() })
        captureQueue.async {
            do {
                try self.setupAudioVideoSession()
            } catch let error as NSError {
                print("Error configuring AV Session: \(error)")
            }
        }
    }
    
    func start() -> Int32 {
        self.updateFrameOrientation()
        self.capturing = true
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
        
        NotificationCenter.default.removeObserver(self,
                                                  name: UIDevice.orientationDidChangeNotification,
                                                  object: nil)
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
    
    fileprivate var hasMultipleCameras: Bool {
        guard #available(iOS 10, *) else { return false }
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices.count > 1
    }
    
    func setCameraPosition(_ position: AVCaptureDevice.Position) -> Bool {
        guard let preset = captureSession?.sessionPreset else {
            return false
        }
        
        let newVideoInput: AVCaptureDeviceInput? = {
            do {
                if position == AVCaptureDevice.Position.back {
                    guard let backFacingCamera = backFacingCamera() else { return nil }
                    return try AVCaptureDeviceInput.init(device: backFacingCamera)
                } else if position == AVCaptureDevice.Position.front {
                    guard let frontFacingCamera = frontFacingCamera() else { return nil }
                    return try AVCaptureDeviceInput.init(device: frontFacingCamera)
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
            guard let videoInput = self.videoInput else { return }
            captureSession?.removeInput(videoInput)
            
            if captureSession?.canAddInput(newInput) ?? false {
                captureSession?.addInput(newInput)
                self.videoInput = newInput
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
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropping frame")
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        guard capturing,
              let videoCaptureConsumer = videoCaptureConsumer,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else {
                print("Error acquiring sample buffer")
                return
        }
        
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        videoCaptureConsumer.consumeImageBuffer(imageBuffer, orientation: videoFrameOrientation, timestamp: time, metadata: videoFrame.metadata)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
}
