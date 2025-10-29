//
//  CustomRenderView.swift
//  Basic-Video-Renderer
//
//  Created by Artur Osiński on 27/10/2025.
//  Copyright © 2025 Vonage. All rights reserved.
//

import OpenTok

class CustomRenderView: UIView {
    
    // MARK: - Properties
    var renderQueue: DispatchQueue
    private var image: CGImage?
    
    // MARK: - Init
    override init(frame: CGRect) {
        self.renderQueue = DispatchQueue.global(qos: .userInitiated)
        super.init(frame: frame)
        self.image = nil
    }
    
    required init?(coder: NSCoder) {
        self.renderQueue = DispatchQueue.global(qos: .userInitiated)
        super.init(coder: coder)
        self.image = nil
    }
    
    // MARK: - Render Video Frame
    func renderVideoFrame(_ frame: OTVideoFrame) {
        let frameToRender = frame
        
        renderQueue.sync {
            // Release previous image if any exists
            if image != nil {
                image = nil
            }
            guard let format = frame.format else { return }
            let width = Int(format.imageWidth)
            let height = Int(format.imageHeight)
            let bufferSize = width * height * 3
            
            guard let rawYPlane = frameToRender.planes?.pointer(at: 0) else { return }
            let yplane = rawYPlane.bindMemory(to: UInt8.self, capacity: width * height)
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            
            // Fill RGB buffer with grayscale image (Y only)
            for i in 0..<height {
                for j in 0..<width {
                    let pixelIndex = (i * width * 3) + (j * 3)
                    let yValue = yplane[(i * width) + j]
                    buffer[pixelIndex] = yValue
                    buffer[pixelIndex + 1] = yValue
                    buffer[pixelIndex + 2] = yValue
                }
            }
            
            // Release buffer when CGDataProvider is done
            let releaseCallback: CGDataProviderReleaseDataCallback = { _, data, _ in
                data.deallocate()
            }
            
            guard let provider = CGDataProvider(dataInfo: nil, data: buffer, size: bufferSize, releaseData: releaseCallback) else {
                buffer.deallocate()
                return
            }
            
            // Create CGImage
            image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 24,
                bytesPerRow: 3 * width,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.setNeedsDisplay()
            }
        }
    }
        
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        var imgCopy: CGImage?
        
        renderQueue.sync {
            if let currentImage = image {
                imgCopy = currentImage.copy()
            }
        }
        
        if let img = imgCopy {
            context.draw(img, in: self.bounds)
        }
    }
}
