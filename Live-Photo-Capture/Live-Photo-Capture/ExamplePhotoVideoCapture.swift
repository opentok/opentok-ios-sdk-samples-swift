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
    
    private func doPhotoCapture(completionHandler handler: @escaping (_ photo: UIImage?) -> ()) {
        guard let connection:AVCaptureConnection = stillImageOutput?.connections.filter({ conn -> Bool in
            (conn as! AVCaptureConnection).inputPorts.contains( where: {
                return ($0 as! AVCaptureInputPort).mediaType == AVMediaTypeVideo
            })
        }).first as? AVCaptureConnection
            else {
                handler(nil)
                return
        }

        stillImageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { (buffer, error) in
            let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
            let resultImage = UIImage(data: data!)
            handler(resultImage)
        })
    }
    
    func takePhoto(completionHandler handler: @escaping (_ photo: UIImage?) -> ()) {
        captureQueue.async {
            self.pauseVideoCaptureForPhoto()
            self.doPhotoCapture(completionHandler: { img in
                DispatchQueue.main.async {
                    handler(img)
                }
            })
            self.resumeVideoCapture()
        }
    }
 }
