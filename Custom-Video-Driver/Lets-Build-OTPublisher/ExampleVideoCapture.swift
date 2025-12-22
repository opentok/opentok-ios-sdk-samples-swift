//
//  ExampleVideoCapture.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import OpenTok
import AVFoundation
import Vision

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
    
    // Properties for freeze detection
    private var previousImageBuffer: CVPixelBuffer?
    private var consecutiveFrozenFrames = 0
    private let frozenThreshold: Float = 0.1 // Threshold for both methods
    private let useDirectComparison = false // Flag to switch between methods
    
    // Property to control video publishing
    private var isVideoEnabled = true
    
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
        
        // Freeze detection using either direct comparison or optical flow
        if let previousBuffer = previousImageBuffer {
            var difference: Float = 1.0
            
            if useDirectComparison {
                // Method 1: Direct frame comparison
                difference = compareFrames(current: imageBuffer, previous: previousBuffer)
                print("Direct comparison difference: \(difference)")
            } else {
                // Method 2: Optical flow using Vision
                let request = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: imageBuffer, options: [:])
                request.computationAccuracy = .high
                let handler = VNImageRequestHandler(cvPixelBuffer: previousBuffer, options: [:])
                
                do {
                    try handler.perform([request])
                    
                    if let observations = request.results,
                       let flowObservation = observations.first as? VNPixelBufferObservation {
                        let flowPixelBuffer = flowObservation.pixelBuffer
                        difference = calculateMotionMagnitude(from: flowPixelBuffer)
                        print("Optical flow magnitude: \(difference)")
                    }
                } catch {
                    print("Vision error: \(error)")
                }
            }
            
            // Process the difference value the same way for both methods
            if difference < frozenThreshold {
                consecutiveFrozenFrames += 1
                print("Low motion: \(difference) < \(frozenThreshold), consecutive: \(consecutiveFrozenFrames)")
                if consecutiveFrozenFrames > 5 { // About 1/6 second at 30fps
                    print("frozen")
                }
            } else {
                consecutiveFrozenFrames = 0
                print("moving")
            }
        }
        
        // Store current frame for next comparison
        previousImageBuffer = imageBuffer
        
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        videoCaptureConsumer.consumeImageBuffer(imageBuffer, orientation: videoFrameOrientation, timestamp: time, metadata: videoFrame.metadata)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
    
    private func calculateMotionMagnitude(from flowPixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(flowPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(flowPixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(flowPixelBuffer)
        let height = CVPixelBufferGetHeight(flowPixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(flowPixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(flowPixelBuffer)!
        
        var magnitudes: [Float] = []
        
        // Sample the flow buffer
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let offset = y * bytesPerRow + x * 8 // 2 float32 values per pixel
                let flowX = baseAddress.load(fromByteOffset: offset, as: Float32.self)
                let flowY = baseAddress.load(fromByteOffset: offset + 4, as: Float32.self)
                
                // Calculate magnitude of the flow vector
                let magnitude = sqrt(flowX * flowX + flowY * flowY)
                magnitudes.append(Float(magnitude))
            }
        }
        
        // Sort magnitudes and take median to reduce impact of outliers
        magnitudes.sort()
        let medianIndex = magnitudes.count / 2
        let medianMagnitude = magnitudes.isEmpty ? 0 : magnitudes[medianIndex]
        
        print("Motion magnitude (median): \(medianMagnitude)")
        
        return medianMagnitude
    }
}

/**
 * Compares two video frames to determine how different they are.
 * 
 * This function:
 * 1. Takes samples of pixel values from both frames
 * 2. Calculates the absolute difference between corresponding pixels
 * 3. Returns a value between 0.0 and 1.0 representing the average difference
 *    - 0.0 means frames are identical (completely frozen)
 *    - 1.0 means frames are completely different (maximum movement)
 *
 * @param current The current video frame
 * @param previous The previous video frame
 * @return A float value between 0.0 and 1.0 representing the difference
 */
private func compareFrames(current: CVPixelBuffer, previous: CVPixelBuffer) -> Float {
    // Lock buffers to safely access pixel data
    CVPixelBufferLockBaseAddress(current, .readOnly)
    CVPixelBufferLockBaseAddress(previous, .readOnly)
    
    defer {
        // Ensure buffers are unlocked even if an error occurs
        CVPixelBufferUnlockBaseAddress(current, .readOnly)
        CVPixelBufferUnlockBaseAddress(previous, .readOnly)
    }
    
    let width = CVPixelBufferGetWidth(current)
    let height = CVPixelBufferGetHeight(current)
    
    // Sample a subset of pixels for performance (every 20th pixel)
    let sampleStep = 20
    var totalDifference: Float = 0
    var sampleCount = 0
    
    // Get base addresses for Y plane (luminance data in NV12 format)
    guard let currentBaseAddress = CVPixelBufferGetBaseAddressOfPlane(current, 0),
          let previousBaseAddress = CVPixelBufferGetBaseAddressOfPlane(previous, 0) else {
        return 1.0 // Return high difference if we can't access the data
    }
    
    let currentBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(current, 0)
    let previousBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(previous, 0)
    
    // Compare Y plane values (luminance)
    for y in stride(from: 0, to: height, by: sampleStep) {
        for x in stride(from: 0, to: width, by: sampleStep) {
            let currentOffset = y * currentBytesPerRow + x
            let previousOffset = y * previousBytesPerRow + x
            
            // Get pixel values from both frames
            let currentValue = currentBaseAddress.load(fromByteOffset: currentOffset, as: UInt8.self)
            let previousValue = previousBaseAddress.load(fromByteOffset: previousOffset, as: UInt8.self)
            
            // Calculate normalized difference (0.0-1.0)
            let difference = abs(Float(currentValue) - Float(previousValue)) / 255.0
            totalDifference += difference
            sampleCount += 1
        }
    }
    
    // Calculate average difference across all sampled pixels
    let averageDifference = sampleCount > 0 ? totalDifference / Float(sampleCount) : 0
    print("Frame difference: \(averageDifference)")
    
    return averageDifference
}
