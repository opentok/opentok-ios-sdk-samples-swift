//
//  ExamplePhotoVideoCapture.swift
//  Live-Photo-Capture
//
//  Created by Roberto Perez Cubero on 23/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import AVFoundation

class ExamplePhotoVideoCapture: ExampleVideoCapture {
    var stillImageOutput: AVCaptureStillImageOutput?
    var oldPreset: String?
    
    private func waitForSensor() {
        let now = CACurrentMediaTime()
        let timeout = 1.0
        
        while (timeout > (CACurrentMediaTime() - now))
            && (videoInput!.device.isAdjustingExposure || videoInput!.device.isAdjustingFocus) {}
        return
    }
    
    private func pauseVideoCaptureForPhoto() {
        captureSession?.beginConfiguration()
        oldPreset = captureSession?.sessionPreset
        captureSession?.sessionPreset = AVCaptureSessionPresetPhoto
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        captureSession?.addOutput(stillImageOutput)
        captureSession?.commitConfiguration()
        
        waitForSensor()
    }
    
    private func resumeVideoCapture() {
        captureSession?.beginConfiguration()
        captureSession?.sessionPreset = oldPreset
        captureSession?.removeOutput(stillImageOutput)
        captureSession?.commitConfiguration()
    }
    
    private func doPhotoCapture() -> UIImage? {
        guard let connection:AVCaptureConnection = stillImageOutput?.connections.filter({ conn -> Bool in
            (conn as! AVCaptureConnection).inputPorts.contains( where: {
                return ($0 as! AVCaptureInputPort).mediaType == AVMediaTypeVideo
            })
        }).first as? AVCaptureConnection
            else {
                return nil
        }
        
        let sem = DispatchSemaphore(value: 0)
        var resultImage: UIImage? = nil
        stillImageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { (buffer, error) in
            let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
            resultImage = UIImage(data: data!)
            sem.signal()
        })
        
        let time = Double(30) * Double(NSEC_PER_SEC)
        let timeout =  DispatchTime.init(uptimeNanoseconds: UInt64(time))
        let _ = sem.wait(timeout: timeout)
        return resultImage
    }
    
    func takePhoto(completionHandler handler: @escaping (_ photo: UIImage?) -> ()) {
        captureQueue.async {
            self.pauseVideoCaptureForPhoto()
            let image = self.doPhotoCapture()
            DispatchQueue.main.async {
                handler(image)
            }
            
            self.resumeVideoCapture()
        }
    }
 }
