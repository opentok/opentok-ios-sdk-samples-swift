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
    var oldPreset: AVCaptureSession.Preset?
    
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
        captureSession?.sessionPreset = AVCaptureSession.Preset.photo
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecType.jpeg]
        guard let stillImageOutput = self.stillImageOutput else {
            print("Error setting stillImageOutput")
            return
        }
        captureSession?.addOutput(stillImageOutput)
        captureSession?.commitConfiguration()
        
        waitForSensor()
    }
    
    private func resumeVideoCapture() {
        captureSession?.beginConfiguration()
        guard let oldPreset = oldPreset else {
            print("Error get oldPreset")
            return
        }
        captureSession?.sessionPreset = oldPreset
        guard let stillImageOutput = self.stillImageOutput else {
            print("Error setting stillImageOutput")
            return
        }
        captureSession?.removeOutput(stillImageOutput)
        captureSession?.commitConfiguration()
    }
    
    private func doPhotoCapture(completionHandler handler: @escaping (_ photo: UIImage?) -> ()) {
        guard let connection:AVCaptureConnection = stillImageOutput?.connections.filter({ conn -> Bool in
            (conn ).inputPorts.contains( where: {
                return ($0 ).mediaType == AVMediaType.video
            })
        }).first
            else {
                handler(nil)
                return
        }

        stillImageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { (buffer, error) in
            guard let buffer = buffer else {
                print("Error gettinb buffer")
                return
            }
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
