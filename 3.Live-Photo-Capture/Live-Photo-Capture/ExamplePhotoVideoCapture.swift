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
            && (videoInput!.device.adjustingExposure || videoInput!.device.adjustingFocus) {}
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
            (conn as! AVCaptureConnection).inputPorts.contains( {
                return ($0 as! AVCaptureInputPort).mediaType == AVMediaTypeVideo
            })
        }).first as? AVCaptureConnection
            else {
                return nil
        }
        
        let sem = dispatch_semaphore_create(0)
        var resultImage: UIImage? = nil
        stillImageOutput?.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (buffer, error) in
            let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
            resultImage = UIImage(data: data)
            dispatch_semaphore_signal(sem)
        })
        
        let timeout =  dispatch_time(DISPATCH_TIME_NOW, Int64(30 * Double(NSEC_PER_SEC)))
        dispatch_semaphore_wait(sem, timeout)
        return resultImage
    }
    
    func takePhoto(completionHandler handler: (photo: UIImage?) -> ()) {
        dispatch_async(captureQueue) {
            self.pauseVideoCaptureForPhoto()
            let image = self.doPhotoCapture()
            dispatch_async(dispatch_get_main_queue()) {
                handler(photo: image)
            }
            
            self.resumeVideoCapture()
        }
    }
 }