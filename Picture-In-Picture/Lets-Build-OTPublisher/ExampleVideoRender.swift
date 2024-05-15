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
        if pixelBufferRef == nil {
            print("No PixelBuffer refrance found")
            return vImage_Error(kvImageInvalidParameter)
        }

        let width = frame.format?.imageWidth ?? 0
        let height = frame.format?.imageHeight ?? 0
        let subsampledWidth = frame.format!.imageWidth/2
        let subsampledHeight = frame.format!.imageHeight/2
        let planeSize = calculatePlaneSize(forFrame: frame)

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
    
    var frameLock = NSLock()
    var bufferDisplayLayer =  AVSampleBufferDisplayLayer()
    var pipBufferDisplayLayer: AVSampleBufferDisplayLayer?
    let accel = Accelerater()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension ExampleVideoRender: OTVideoRender {
    func renderVideoFrame(_ frame: OTVideoFrame) {
        if let format = frame.format {
            frameLock.lock()
            assert(format.pixelFormat == .I420)
            
            if let sampleBuffer = createSampleBufferWithVideoFrame(frame,
                                                                   width: Int(frame.format!.imageWidth),
                                                                   height: Int(frame.format!.imageHeight)) {
                bufferDisplayLayer.enqueue(sampleBuffer)
                pipBufferDisplayLayer?.enqueue(sampleBuffer)
            }
            
            frameLock.unlock()
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
        
        if osStatus != noErr {
            let errorMessage = osStatusToString(status: osStatus)
            print("osStatus error: \(errorMessage)")
        }
        
        guard let buffer = sampleBuffer else {
            print("Cannot create sample buffer")
            return nil
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        return buffer
    }
    
    func osStatusToString(status: OSStatus) -> String {
        switch status {
        case kCMSampleBufferError_DataCanceled:
            return "kCMSampleBufferError_DataCanceled"
        case kCMSampleBufferError_DataFailed:
            return "kCMSampleBufferError_DataFailed"
        case kCMSampleBufferError_Invalidated:
            return "kCMSampleBufferError_Invalidated"
        case kCMSampleBufferError_InvalidMediaFormat:
            return "kCMSampleBufferError_InvalidMediaFormat"
        case kCMSampleBufferError_InvalidSampleData:
            return "kCMSampleBufferError_InvalidSampleData"
        case kCMSampleBufferError_InvalidMediaTypeForOperation:
            return "kCMSampleBufferError_InvalidMediaTypeForOperation"
        case kCMSampleBufferError_SampleTimingInfoInvalid:
            return "kCMSampleBufferError_SampleTimingInfoInvalid"
        case kCMSampleBufferError_CannotSubdivide:
            return "kCMSampleBufferError_CannotSubdivide"
        case kCMSampleBufferError_InvalidEntryCount:
            return "kCMSampleBufferError_InvalidEntryCount"
        case kCMSampleBufferError_ArrayTooSmall:
            return "kCMSampleBufferError_ArrayTooSmall"
        case kCMSampleBufferError_BufferHasNoSampleTimingInfo:
            return "kCMSampleBufferError_BufferHasNoSampleTimingInfo"
        case kCMSampleBufferError_BufferHasNoSampleSizes:
            return "kCMSampleBufferError_BufferHasNoSampleSizes"
        case kCMSampleBufferError_SampleIndexOutOfRange:
            return "kCMSampleBufferError_SampleIndexOutOfRange"
        case kCMSampleBufferError_BufferNotReady:
            return "kCMSampleBufferError_BufferNotReady"
        case kCMSampleBufferError_AlreadyHasDataBuffer:
            return "kCMSampleBufferError_AlreadyHasDataBuffer"
        case kCMSampleBufferError_RequiredParameterMissing:
            return "kCMSampleBufferError_RequiredParameterMissing"
        case kCMSampleBufferError_AllocationFailed:
            return "kCMSampleBufferError_AllocationFailed"
        default:
            return "Unknown error with code \(status)"
        }
    }
    
  }

