//
//  ExampleVideoRender.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import OpenTok
import GLKit
import Foundation
import Accelerate
import UIKit

class Accelerater{
    var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
    init() {
        _ = configureYpCbCrToARGBInfo()
    }

    func configureYpCbCrToARGBInfo() -> vImage_Error {
        print("Configuring")
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 0,
                                                 CbCr_bias: 128,
                                                 YpRangeMax: 255,
                                                 CbCrRangeMax: 255,
                                                 YpMax: 255,
                                                 YpMin: 1,
                                                 CbCrMax: 255,
                                                 CbCrMin: 0)

        let error = vImageConvert_YpCbCrToARGB_GenerateConversion(
            kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!,
            &pixelRange,
            &infoYpCbCrToARGB,
            kvImage420Yp8_Cb8_Cr8,
            kvImageARGB8888,
            vImage_Flags(kvImagePrintDiagnosticsToConsole))



        print("Configration done \(error)")
        return error
    }

    func convertFrameVImageYUV(_ frame: OTVideoFrame, to pixelBufferRef: CVPixelBuffer?) -> vImage_Error{
        let start  = CFAbsoluteTimeGetCurrent()
        if pixelBufferRef == nil {
            print("No PixelBuffer refrance found")
            return vImage_Error(kvImageInvalidParameter)
        }

        let width = frame.format?.imageWidth ?? 0
        let height = frame.format?.imageHeight ?? 0
        let subsampledWidth = frame.format!.imageWidth/2
        let subsampledHeight = frame.format!.imageHeight/2
//        print("subsample height \(subsampledHeight) \(subsampledWidth)")
        let planeSize = calculatePlaneSize(forFrame: frame)

//        print("ysize : \(planeSize.ySize) \(planeSize.uSize) \(planeSize.vSize)")
        let yPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.ySize)
        let uPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.uSize)
        let vPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.vSize)

        memcpy(yPlane, frame.planes?.pointer(at: 0), planeSize.ySize)
        memcpy(uPlane, frame.planes?.pointer(at: 1), planeSize.uSize)
        memcpy(vPlane, frame.planes?.pointer(at: 2), planeSize.vSize)

        let yStride = frame.format!.bytesPerRow.object(at: 0) as! Int
        // multiply chroma strides by 2 as bytesPerRow represents 2x2 subsample
        let uStride = frame.format!.bytesPerRow.object(at: 1) as! Int
        let vStride = frame.format!.bytesPerRow.object(at: 2) as! Int

        var yPlaneBuffer = vImage_Buffer(data: yPlane, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: yStride)

        var uPlaneBuffer = vImage_Buffer(data: uPlane, height: vImagePixelCount(subsampledHeight), width: vImagePixelCount(subsampledWidth), rowBytes: uStride)


        var vPlaneBuffer = vImage_Buffer(data: vPlane, height: vImagePixelCount(subsampledHeight), width: vImagePixelCount(subsampledWidth), rowBytes: vStride)
        CVPixelBufferLockBaseAddress(pixelBufferRef!, .readOnly)
        let pixelBufferData = CVPixelBufferGetBaseAddress(pixelBufferRef!)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBufferRef!)
        var destinationImageBuffer = vImage_Buffer()
        destinationImageBuffer.data = pixelBufferData
        destinationImageBuffer.height = vImagePixelCount(height)
        destinationImageBuffer.width = vImagePixelCount(width)
        destinationImageBuffer.rowBytes = rowBytes

        var permuteMap: [UInt8] = [3, 2, 1, 0] // BGRA
        let convertError = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&yPlaneBuffer, &uPlaneBuffer, &vPlaneBuffer, &destinationImageBuffer, &infoYpCbCrToARGB, &permuteMap, 255, vImage_Flags(kvImagePrintDiagnosticsToConsole))

        CVPixelBufferUnlockBaseAddress(pixelBufferRef!, [])


        yPlane.deallocate()
        uPlane.deallocate()
        vPlane.deallocate()
        let end = CFAbsoluteTimeGetCurrent()
//        print("Decoding time \((end-start)*1000)")
        return convertError

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

protocol ExampleVideoRenderDelegate {
    func renderer(_ renderer: ExampleVideoRender, didReceiveFrame videoFrame: OTVideoFrame)
}

class ExampleVideoRender: UIView {
    
    var delegate: ExampleVideoRenderDelegate?
    
    fileprivate var frameLock: NSLock?
    var bufferDisplayLayer: AVSampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    let accel = Accelerater()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        frameLock = NSLock()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

extension ExampleVideoRender: OTVideoRender {
    func renderVideoFrame(_ frame: OTVideoFrame) {
        if let fLock = frameLock, let format = frame.format {
            fLock.lock()
            assert(format.pixelFormat == .I420)
            
            if let sampleBuffer = createSampleBufferWithVideoFrame(frame,
                                                                   width: Int(frame.format!.imageWidth),
                                                                   height: Int(frame.format!.imageHeight)) {
                bufferDisplayLayer.enqueue(sampleBuffer)
            }
            
            fLock.unlock()
        }
    }
    
    
    func createSampleBufferWithVideoFrame(_ frame: OTVideoFrame, width: Int, height: Int) -> CMSampleBuffer? {
        
        let pixelAttributes: NSDictionary = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, pixelAttributes as CFDictionary, &pixelBuffer)
        
        guard result == 0 else {
            return nil
        }
        _ = accel.convertFrameVImageYUV(frame, to: pixelBuffer)
        let s = createSampleBufferFrom(pixelBuffer: pixelBuffer!)
        
        
        return s
    }
    
    func createSampleBufferFrom(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        var sampleBuffer: CMSampleBuffer?
        
        
        let now = CMTimeMakeWithSeconds(CACurrentMediaTime(), preferredTimescale: 1000)
        var timingInfo = CMSampleTimingInfo(duration: CMTimeMakeWithSeconds(1, preferredTimescale: 1000), presentationTimeStamp: now, decodeTimeStamp: now)
        var formatDescription: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        
        let osStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        //        print("osStatus CMSampleBufferCreateReadyWithImageBuffer = \(osStatus)")
        // Print out errors
        if osStatus == kCMSampleBufferError_AllocationFailed {
            print("osStatus == kCMSampleBufferError_AllocationFailed")
        }
        if osStatus == kCMSampleBufferError_RequiredParameterMissing {
            print("osStatus == kCMSampleBufferError_RequiredParameterMissing")
        }
        if osStatus == kCMSampleBufferError_AlreadyHasDataBuffer {
            print("osStatus == kCMSampleBufferError_AlreadyHasDataBuffer")
        }
        if osStatus == kCMSampleBufferError_BufferNotReady {
            print("osStatus == kCMSampleBufferError_BufferNotReady")
        }
        if osStatus == kCMSampleBufferError_SampleIndexOutOfRange {
            print("osStatus == kCMSampleBufferError_SampleIndexOutOfRange")
        }
        if osStatus == kCMSampleBufferError_BufferHasNoSampleSizes {
            print("osStatus == kCMSampleBufferError_BufferHasNoSampleSizes")
        }
        if osStatus == kCMSampleBufferError_BufferHasNoSampleTimingInfo {
            print("osStatus == kCMSampleBufferError_BufferHasNoSampleTimingInfo")
        }
        if osStatus == kCMSampleBufferError_ArrayTooSmall {
            print("osStatus == kCMSampleBufferError_ArrayTooSmall")
        }
        if osStatus == kCMSampleBufferError_InvalidEntryCount {
            print("osStatus == kCMSampleBufferError_InvalidEntryCount")
        }
        if osStatus == kCMSampleBufferError_CannotSubdivide {
            print("osStatus == kCMSampleBufferError_CannotSubdivide")
        }
        if osStatus == kCMSampleBufferError_SampleTimingInfoInvalid {
            print("osStatus == kCMSampleBufferError_SampleTimingInfoInvalid")
        }
        if osStatus == kCMSampleBufferError_InvalidMediaTypeForOperation {
            print("osStatus == kCMSampleBufferError_InvalidMediaTypeForOperation")
        }
        if osStatus == kCMSampleBufferError_InvalidSampleData {
            print("osStatus == kCMSampleBufferError_InvalidSampleData")
        }
        if osStatus == kCMSampleBufferError_InvalidMediaFormat {
            print("osStatus == kCMSampleBufferError_InvalidMediaFormat")
        }
        if osStatus == kCMSampleBufferError_Invalidated {
            print("osStatus == kCMSampleBufferError_Invalidated")
        }
        if osStatus == kCMSampleBufferError_DataFailed {
            print("osStatus == kCMSampleBufferError_DataFailed")
        }
        if osStatus == kCMSampleBufferError_DataCanceled {
            print("osStatus == kCMSampleBufferError_DataCanceled")
        }
        
        guard let buffer = sampleBuffer else {
            print("Cannot create sample buffer")
            return nil
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        return buffer
    }
    
    
    func makeSampleBuffer() -> CMSampleBuffer? {
        let scale = UIScreen.main.scale
        let size = CGSize(
            width: (bounds.width * scale),
            height: (bounds.height * scale))
        
        var pixelBuffer: CVPixelBuffer?
        var status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(size.width),
                                         Int(size.height),
                                         kCVPixelFormatType_32ARGB,
                                         [
                                            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                                            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
                                            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
                                         ] as CFDictionary, &pixelBuffer)
        
        if status != kCVReturnSuccess {
            assertionFailure("[UIPiPView] Failed to create CVPixelBuffer: \(status)")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer!, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer!),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: scale, y: -scale)
        layer.render(in: context)
        
        var formatDescription: CMFormatDescription?
        status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer!,
            formatDescriptionOut: &formatDescription)
        
        if status != kCVReturnSuccess {
            assertionFailure("[UIPiPView] Failed to create CMFormatDescription: \(status)")
            return nil
        }
        
        let now = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 60)
        let timingInfo = CMSampleTimingInfo(
            duration: .init(seconds: 1, preferredTimescale: 60),
            presentationTimeStamp: now,
            decodeTimeStamp: now)
        
        do {
            if #available(iOS 13.0, *) {
                return try CMSampleBuffer(
                    imageBuffer: pixelBuffer!,
                    formatDescription: formatDescription!,
                    sampleTiming: timingInfo)
            } else {
                assertionFailure("[UIPiPView] UIPiPView cannot be used on this device or OS.")
                return nil
            }
        } catch {
            assertionFailure("[UIPiPView] Failed to create CVSampleBuffer: \(error)")
            return nil
        }
    }
    
  }

