//
//  ScreenCapturer.swift
//  5.Screen-Sharing
//
//  Created by Roberto Perez Cubero on 23/09/2016.
//  Copyright © 2016 tokbox. All rights reserved.
//

import Foundation
import OpenTok

class ScreenCapturer: NSObject, OTVideoCapture {
    var videoCaptureConsumer: OTVideoCaptureConsumer?

    let MAX_EDGE_SIZE_LIMIT: CGFloat = 1280.0
    let EDGE_DIMENSION_COMMON_FACTOR: CGFloat = 16.0
    
    fileprivate let captureView: UIView
    fileprivate let captureQueue = DispatchQueue(label: "ot-screen-capture")
    fileprivate var timer: DispatchSourceTimer
    fileprivate var capturing: Bool = false
    fileprivate var videoFrame = OTVideoFrame(format: OTVideoFormat(argbWithWidth: 0, height: 0))
    fileprivate var pixelBuffer: CVPixelBuffer?
    
    init(withView: UIView) {
        captureView = withView        
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: captureQueue)
    }
    fileprivate func screenShoot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(captureView.bounds.size, false, 0.0)
        captureView.drawHierarchy(in: captureView.bounds, afterScreenUpdates: false)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    fileprivate func resizeAndPad(image img: UIImage) -> CGImage {
        let source = img.cgImage!
        let size = CGSize(width: source.width, height: source.height)
        let destSizes = dimensions(forInputSize: size)
        
        UIGraphicsBeginImageContextWithOptions(destSizes.container, false, 1.0)
        let ctx = UIGraphicsGetCurrentContext()
        
        ctx?.scaleBy(x: 1, y: -1)
        ctx?.translateBy(x: 0, y: -destSizes.rect.size.height)
        ctx?.draw(source, in: destSizes.rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return (newImage?.cgImage)!
    }
    
    fileprivate func consume(frame: CGImage) {
        checkSize(forImage: frame)
        
        if !capturing {
            return
        }
        
        let timeStamp = mach_absolute_time()
        let time = CMTime(seconds: Double(timeStamp), preferredTimescale: 1000)
        let ref = pixelBuffer(fromCGImage: frame)
        
        CVPixelBufferLockBaseAddress(ref, CVPixelBufferLockFlags(rawValue: 0))
        
        videoFrame.timestamp = time
        //videoFrame?.format.estimatedFramesPerSecond =
        videoFrame.format?.estimatedCaptureDelay = 100
        videoFrame.orientation = .up
        
        videoFrame.clearPlanes()
        videoFrame.planes?.addPointer(CVPixelBufferGetBaseAddress(ref))        
        videoCaptureConsumer?.consumeFrame(videoFrame)
        
        CVPixelBufferUnlockBaseAddress(ref, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
    
    // MARK: - OTVideoCapture protocol
    func initCapture() {
        timer.setEventHandler { 
            let screen = self.screenShoot()
            let padded = self.resizeAndPad(image: screen)
            self.consume(frame: padded)
        }
        timer.scheduleRepeating(deadline: DispatchTime.now(), interval: DispatchTimeInterval.milliseconds(100))
    }
    
    func start() -> Int32 {
        capturing = true
        captureQueue.sync {
            timer.resume()
        }
        return 0
    }
    
    func stop() -> Int32 {
        capturing = false
        captureQueue.sync {
            timer.cancel()
        }
        return 0
    }
    
    func releaseCapture() {
        timer.cancel()
    }
    
    func isCaptureStarted() -> Bool {
        return capturing
    }
    
    func captureSettings(_ videoFormat: OTVideoFormat) -> Int32 {
        videoFormat.pixelFormat = .ARGB
        return 0
    }
}

// MARK: - Image Utils
extension ScreenCapturer {
    fileprivate func pixelBuffer(fromCGImage img: CGImage) -> CVPixelBuffer {
        let frameSize = CGSize(width: img.width, height: img.height)
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        let pxdata = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context =
            CGContext(data: pxdata,
                      width: Int(frameSize.width),
                      height: Int(frameSize.height),
                      bitsPerComponent: 8,
                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                      space: rgbColorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        
        context?.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        return pixelBuffer!;
    }
    
    fileprivate func dimensions(forInputSize size: CGSize) -> (container: CGSize, rect: CGRect) {
        let aspect = size.width / size.height
        
        var destContainer = CGSize(width: size.width, height: size.height)
        var destFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
        
        // if image is wider than tall and width breaks edge size limit
        if MAX_EDGE_SIZE_LIMIT < size.width && aspect >= 1.0 {
            destContainer.width = MAX_EDGE_SIZE_LIMIT
            destContainer.height = destContainer.width / aspect
            if 0 != fmod(destContainer.height, EDGE_DIMENSION_COMMON_FACTOR) {
                destContainer.height +=
                    (EDGE_DIMENSION_COMMON_FACTOR - fmod(destContainer.height, EDGE_DIMENSION_COMMON_FACTOR))
            }
            destFrame.size.width = destContainer.width
            destFrame.size.height = destContainer.width / aspect
        }
        
        // ensure the dimensions of the resulting container are safe
        if (fmod(destContainer.width, EDGE_DIMENSION_COMMON_FACTOR) != 0) {
            let remainder = fmod(destContainer.width,
                                 EDGE_DIMENSION_COMMON_FACTOR);
            // increase the edge size only if doing so does not break the edge limit
            if (destContainer.width + (EDGE_DIMENSION_COMMON_FACTOR - remainder) >
                MAX_EDGE_SIZE_LIMIT)
            {
                destContainer.width -= remainder;
            } else {
                destContainer.width += EDGE_DIMENSION_COMMON_FACTOR - remainder;
            }
        }
        // ensure the dimensions of the resulting container are safe
        if (fmod(destContainer.height, EDGE_DIMENSION_COMMON_FACTOR) != 0) {
            let remainder = fmod(destContainer.height,
                                 EDGE_DIMENSION_COMMON_FACTOR);
            // increase the edge size only if doing so does not break the edge limit
            if (destContainer.height + (EDGE_DIMENSION_COMMON_FACTOR - remainder) >
                MAX_EDGE_SIZE_LIMIT)
            {
                destContainer.height -= remainder;
            } else {
                destContainer.height += EDGE_DIMENSION_COMMON_FACTOR - remainder;
            }
        }
        
        destFrame.size.width = destContainer.width;
        destFrame.size.height = destContainer.height;
        
        // scale and recenter source image to fit in destination container
        if (aspect > 1.0) {
            destFrame.origin.x = 0;
            destFrame.origin.y =
                (destContainer.height - destContainer.width) / 2;
            destFrame.size.width = destContainer.width;
            destFrame.size.height =
                destContainer.width / aspect;
        } else {
            destFrame.origin.x =
                (destContainer.width - destContainer.width) / 2;
            destFrame.origin.y = 0;
            destFrame.size.height = destContainer.height;
            destFrame.size.width =
                destContainer.height * aspect;
        }
        
        return (destContainer, destFrame)
    }
    
    fileprivate func checkSize(forImage img: CGImage) {
        guard let frameFormat = videoFrame.format, frameFormat.imageHeight != UInt32(img.height),
            frameFormat.imageWidth != UInt32(img.width)
            else {
                return
        }
        
        frameFormat.bytesPerRow.removeAllObjects()
        frameFormat.bytesPerRow.addObjects(from: [img.width * 4])
        frameFormat.imageWidth = UInt32(img.width)
        frameFormat.imageHeight = UInt32(img.height)
        
        let frameSize = CGSize(width: img.width, height: img.height)
        let options: Dictionary<String, Bool> = [
            kCVPixelBufferCGImageCompatibilityKey as String: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: false
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(frameSize.width),
                                         Int(frameSize.height),
                                         kCVPixelFormatType_32ARGB,
                                         options as CFDictionary,
                                         &pixelBuffer)
        
        assert(status == kCVReturnSuccess && pixelBuffer != nil)
    }
}
