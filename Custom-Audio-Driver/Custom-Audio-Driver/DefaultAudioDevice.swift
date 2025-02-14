//
//  DefaultAudioDevice.swift
//  4.Custom-Audio-Driver
//
//  Created by Roberto Perez Cubero on 21/09/2016.
//  Copyright © 2016 tokbox. All rights reserved.
//

import Foundation
import OpenTok

class DefaultAudioDevice: NSObject {
#if targetEnvironment(simulator)
    static let kSampleRate: UInt16 = 44100
#else
    static let kSampleRate: UInt16 = 48000
#endif
    static let kOutputBus = AudioUnitElement(0)
    static let kInputBus = AudioUnitElement(1)
    static let kAudioDeviceHeadset = "AudioSessionManagerDevice_Headset"
    static let kAudioDeviceBluetooth = "AudioSessionManagerDevice_Bluetooth"
    static let kAudioDeviceSpeaker = "AudioSessionManagerDevice_Speaker"
    static let kToMicroSecond: Double = 1000000
    static let kMaxPlayoutDelay: UInt8 = 150
    static let kMaxRecordingDelay: UInt16 = 500
    
    var audioFormat = OTAudioFormat()
    let safetyQueue = DispatchQueue(label: "ot-audio-driver")

    var deviceAudioBus: OTAudioBus?
    
    func setAudioBus(_ audioBus: OTAudioBus?) -> Bool {
        deviceAudioBus = audioBus
        audioFormat = OTAudioFormat()
        audioFormat.sampleRate = DefaultAudioDevice.kSampleRate
        audioFormat.numChannels = 1
        return true
    }
    
    var bufferList: UnsafeMutablePointer<AudioBufferList>?
    var bufferSize: UInt32 = 0
    var bufferNumFrames: UInt32 = 0
    var playoutAudioUnitPropertyLatency: Float64 = 0
    var playoutDelayMeasurementCounter: UInt32 = 0
    var recordingDelayMeasurementCounter: UInt32 = 0
    var recordingDelay: UInt32 = 0
    var recordingAudioUnitPropertyLatency: Float64 = 0
    var playoutDelay: UInt32 = 0
    var playing = false
    var playoutInitialized = false
    var recording = false
    var recordingInitialized = false
    var interruptedPlayback = false
    var isRecorderInterrupted = false
    var isPlayerInterrupted = false
    var isResetting = false
    var restartRetryCount = 0
    fileprivate var recordingVoiceUnit: AudioUnit?
    fileprivate var playoutVoiceUnit: AudioUnit?
    
    fileprivate var previousAVAudioSessionCategory: AVAudioSession.Category?
    fileprivate var avAudioSessionMode: AVAudioSession.Mode?
    fileprivate var avAudioSessionPreffSampleRate = Double(0)
    fileprivate var avAudioSessionChannels = 0
    fileprivate var isAudioSessionSetup = false
    
    var areListenerBlocksSetup = false
    var streamFormat = AudioStreamBasicDescription()

    override init() {
        audioFormat.sampleRate = DefaultAudioDevice.kSampleRate
        audioFormat.numChannels = 1
    }
    
    deinit {
        tearDownAudio()
        removeObservers()
    }
    
    
    fileprivate func restartAudio() {
        safetyQueue.async {
            self.doRestartAudio(numberOfAttempts: 3)
        }
    }
    
    fileprivate func restartAudioAfterInterruption() {
        if isRecorderInterrupted {
            if startCapture() {
                isRecorderInterrupted = false
                restartRetryCount = 0
            } else {
                restartRetryCount += 1
                if restartRetryCount < 3 {
                    safetyQueue.asyncAfter(deadline: DispatchTime.now(), execute: { [unowned self] in
                        self.restartAudioAfterInterruption()
                    })
                } else {
                    isRecorderInterrupted = false
                    isPlayerInterrupted = false
                    restartRetryCount = 0
                    print("ERROR[OpenTok]:Unable to acquire audio session")
                }
            }
        }
        if isPlayerInterrupted {
            isPlayerInterrupted = false
            let _ = startRendering()
        }
    }
    
    fileprivate func doRestartAudio(numberOfAttempts: Int) {
        isResetting = true
        if recording {
            let _ = stopCapture()
            disposeAudioUnit(audioUnit: &recordingVoiceUnit)
            let _ = startCapture()
        }
        
        if playing {
            let _ = self.stopRendering()
            disposeAudioUnit(audioUnit: &playoutVoiceUnit)
            let _ = self.startRendering()
        }
        isResetting = false
    }
    
    fileprivate func setupAudioUnit(withPlayout playout: Bool) -> Bool {
        if !isAudioSessionSetup {
            setupAudioSession()
            isAudioSessionSetup = true
        }
        
        let bytesPerSample = UInt32(MemoryLayout<Int16>.size)
        streamFormat.mFormatID = kAudioFormatLinearPCM
        streamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        streamFormat.mBytesPerPacket = bytesPerSample
        streamFormat.mFramesPerPacket = 1
        streamFormat.mBytesPerFrame = bytesPerSample
        streamFormat.mChannelsPerFrame = 1
        streamFormat.mBitsPerChannel = 8 * bytesPerSample
        streamFormat.mSampleRate = Float64(DefaultAudioDevice.kSampleRate)
        
        var audioUnitDescription = AudioComponentDescription()
        audioUnitDescription.componentType = kAudioUnitType_Output
        audioUnitDescription.componentSubType = kAudioUnitSubType_VoiceProcessingIO
        audioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple
        audioUnitDescription.componentFlags = 0
        audioUnitDescription.componentFlagsMask = 0
        
        let foundVpioUnitRef = AudioComponentFindNext(nil, &audioUnitDescription)
        let result: OSStatus = {
            if playout {
                return AudioComponentInstanceNew(foundVpioUnitRef!, &playoutVoiceUnit)
            } else {
                return AudioComponentInstanceNew(foundVpioUnitRef!, &recordingVoiceUnit)
            }
        }()
        
        if result != noErr {
            print("Error seting up audio unit")
            return false
        }
        
        var value: UInt32 = 1
        if playout {
            AudioUnitSetProperty(playoutVoiceUnit!, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Output, DefaultAudioDevice.kOutputBus, &value,
                                 UInt32(MemoryLayout<UInt32>.size))
            
            AudioUnitSetProperty(playoutVoiceUnit!, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input, DefaultAudioDevice.kOutputBus, &streamFormat,
                                 UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            // Disable Input on playout
            var enableInput = 0
            AudioUnitSetProperty(playoutVoiceUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input,
                                 DefaultAudioDevice.kInputBus, &enableInput, UInt32(MemoryLayout<UInt32>.size))
        } else {
            AudioUnitSetProperty(recordingVoiceUnit!, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input, DefaultAudioDevice.kInputBus, &value,
                                 UInt32(MemoryLayout<UInt32>.size))
            AudioUnitSetProperty(recordingVoiceUnit!, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, DefaultAudioDevice.kInputBus, &streamFormat,
                                 UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            // Disable Output on record
            var enableOutput = 0
            AudioUnitSetProperty(recordingVoiceUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output,
                                 DefaultAudioDevice.kOutputBus, &enableOutput, UInt32(MemoryLayout<UInt32>.size))
        }
        
        if playout {
            setupPlayoutCallback()
        } else {
            setupRecordingCallback()
        }
        
        setBluetoothAsPreferredInputDevice()
        
        return true
    }
    
    fileprivate func setupPlayoutCallback() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        var renderCallback = AURenderCallbackStruct(inputProc: renderCb, inputProcRefCon: selfPointer)
        AudioUnitSetProperty(playoutVoiceUnit!,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             DefaultAudioDevice.kOutputBus,
                             &renderCallback,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
    }
    
    fileprivate func setupRecordingCallback() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        var inputCallback = AURenderCallbackStruct(inputProc: recordCb, inputProcRefCon: selfPointer)
        AudioUnitSetProperty(recordingVoiceUnit!,
                             kAudioOutputUnitProperty_SetInputCallback,
                             kAudioUnitScope_Global,
                             DefaultAudioDevice.kInputBus,
                             &inputCallback,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        var value = 0
        AudioUnitSetProperty(recordingVoiceUnit!,
                             kAudioUnitProperty_ShouldAllocateBuffer,
                             kAudioUnitScope_Output,
                             DefaultAudioDevice.kInputBus,
                             &value,
                             UInt32(MemoryLayout<UInt32>.size))
    }
    
    fileprivate func disposeAudioUnit(audioUnit: inout AudioUnit?) {
        if let unit = audioUnit {
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }
        audioUnit = nil
    }
    
    fileprivate func tearDownAudio() {
        print("Destoying audio units")
        disposeAudioUnit(audioUnit: &playoutVoiceUnit)
        disposeAudioUnit(audioUnit: &recordingVoiceUnit)
        freeupAudioBuffers()
        
        let session = AVAudioSession.sharedInstance()
        do {
            guard let previousAVAudioSessionCategory = previousAVAudioSessionCategory else { return }
            try session.setCategory(previousAVAudioSessionCategory, mode: .default)
            guard let avAudioSessionMode = avAudioSessionMode else { return }
            try session.setMode(avAudioSessionMode)
            try session.setPreferredSampleRate(avAudioSessionPreffSampleRate)
            try session.setPreferredInputNumberOfChannels(avAudioSessionChannels)
            
            isAudioSessionSetup = false
        } catch {
            print("Error reseting AVAudioSession")
        }
    }
    
    fileprivate func freeupAudioBuffers() {
        if var data = bufferList?.pointee, data.mBuffers.mData != nil {
            data.mBuffers.mData?.assumingMemoryBound(to: UInt16.self).deallocate()
            data.mBuffers.mData = nil
        }
        
        if let list = bufferList {
            list.deallocate()
        }
        
        bufferList = nil
        bufferNumFrames = 0
    }
}

// MARK: - Audio Device Implementation
extension DefaultAudioDevice: OTAudioDevice {
    func  captureFormat() ->  OTAudioFormat {
        return audioFormat
    }
    func renderFormat() -> OTAudioFormat {
        return audioFormat
    }
    func renderingIsAvailable() -> Bool {
        return true
    }
    func renderingIsInitialized() -> Bool {
        return playoutInitialized
    }
    func isRendering() -> Bool {
        return playing
    }
    func isCapturing() -> Bool {
        return recording
    }
    func estimatedRenderDelay() -> UInt16 {
        return UInt16(min(self.playoutDelay, UInt32(DefaultAudioDevice.kMaxPlayoutDelay)))
    }
    func estimatedCaptureDelay() -> UInt16 {
        return UInt16(min(self.recordingDelay, UInt32(DefaultAudioDevice.kMaxRecordingDelay)))
    }
    func captureIsAvailable() -> Bool {
        return true
    }
    func captureIsInitialized() -> Bool {
        return recordingInitialized
    }
    
    func initializeRendering() -> Bool {
        if playing { return false }
        
        playoutInitialized = true
        return playoutInitialized
    }
    
    func startRendering() -> Bool {
        if playing { return true }
        playing = true
        if playoutVoiceUnit == nil {
            playing = setupAudioUnit(withPlayout: true)
            if !playing {
                return false
            }
        }
        
        let result = AudioOutputUnitStart(playoutVoiceUnit!)
        
        if result != noErr {
            print("Error creaing rendering unit")
            playing = false
        }
        return playing
    }
    
    func stopRendering() -> Bool {
        if !playing {
            return true
        }
        
        playing = false
        
        let result = AudioOutputUnitStop(playoutVoiceUnit!)
        if result != noErr {
            print("Error creaing playout unit")
            return false
        }
        
        if !recording && !isPlayerInterrupted && !isResetting {
            tearDownAudio()
        }
        
        return true
    }
    
    
    func initializeCapture() -> Bool {
        if recording { return false }
        
        recordingInitialized = true
        return recordingInitialized
    }
    
    func startCapture() -> Bool {
        if recording {
            return true
        }
        
        recording = true
        
        if recordingVoiceUnit == nil {
            recording = setupAudioUnit(withPlayout: false)
            
            if !recording {
                return false
            }
        }
        
        let result = AudioOutputUnitStart(recordingVoiceUnit!)
        if result != noErr {
            recording = false
        }
        
        return recording
    }
    
    func stopCapture() -> Bool {
        if !recording {
            return true
        }
        
        recording = false
        
        let result = AudioOutputUnitStop(recordingVoiceUnit!)
        
        if result != noErr {
            return false
        }
        
        freeupAudioBuffers()
        
        if !playing && !isRecorderInterrupted && !isResetting {
            tearDownAudio()
        }
        
        return true
    }
    
}

// MARK: - AVAudioSession
extension DefaultAudioDevice {
    @objc func onInterruptionEvent(notification: Notification) {
        let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey]
        safetyQueue.async {
            self.handleInterruptionEvent(type: type as? Int)
        }
    }
    
    fileprivate func handleInterruptionEvent(type: Int?) {
        guard let interruptionType = type else {
            return
        }
        
        switch  UInt(interruptionType) {
        case AVAudioSession.InterruptionType.began.rawValue:
            if recording {
                isRecorderInterrupted = true
                let _ = stopCapture()
            }
            if playing {
                isPlayerInterrupted = true
                let _ = stopRendering()
            }
        case AVAudioSession.InterruptionType.ended.rawValue:
            configureAudioSessionWithDesiredAudioRoute(desiredAudioRoute: DefaultAudioDevice.kAudioDeviceBluetooth)
            restartAudioAfterInterruption()
        default:
            break
        }
    }
    
    @objc func onRouteChangeEvent(notification: Notification) {
        safetyQueue.async {
            self.handleRouteChangeEvent(notification: notification)
        }
    }
    
    @objc func appDidBecomeActive(notification: Notification) {
        safetyQueue.async {
            self.handleInterruptionEvent(type: Int(AVAudioSession.InterruptionType.ended.rawValue))
        }
    }
    
    fileprivate func handleRouteChangeEvent(notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else {
            return
        }
        
        if reason == AVAudioSession.RouteChangeReason.routeConfigurationChange.rawValue {
            return
        }
        
        if reason == AVAudioSession.RouteChangeReason.override.rawValue ||
            reason == AVAudioSession.RouteChangeReason.categoryChange.rawValue {
            
            let oldRouteDesc = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as! AVAudioSessionRouteDescription
            let outputs = oldRouteDesc.outputs
            var oldOutputDeviceName: String? = nil
            var currentOutputDeviceName: String? = nil
            
            if outputs.count > 0 {
                let portDesc = outputs[0]
                oldOutputDeviceName = portDesc.portName
            }
            
            if AVAudioSession.sharedInstance().currentRoute.outputs.count > 0 {
                currentOutputDeviceName = AVAudioSession.sharedInstance().currentRoute.outputs[0].portName
            }
            
            if oldOutputDeviceName == currentOutputDeviceName || currentOutputDeviceName == nil || oldOutputDeviceName == nil {
                return
            }
            
            restartAudio()
        }
    }
    
    fileprivate func setupListenerBlocks() {
        if areListenerBlocksSetup {
            return
        }
        
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(DefaultAudioDevice.onInterruptionEvent),
                                       name: AVAudioSession.interruptionNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(DefaultAudioDevice.onRouteChangeEvent(notification:)),
                                       name: AVAudioSession.routeChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(DefaultAudioDevice.appDidBecomeActive(notification:)),
                                       name: UIApplication.didBecomeActiveNotification, object: nil)
        
        areListenerBlocksSetup = true
    }
    
    fileprivate func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        areListenerBlocksSetup = false
    }
    
    fileprivate func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        
        previousAVAudioSessionCategory = session.category
        avAudioSessionMode = session.mode
        avAudioSessionPreffSampleRate = session.preferredSampleRate
        avAudioSessionChannels = session.inputNumberOfChannels
        do {
            try session.setPreferredSampleRate(Double(DefaultAudioDevice.kSampleRate))
            try session.setPreferredIOBufferDuration(0.01)
            let audioOptions = AVAudioSession.CategoryOptions.mixWithOthers.rawValue |
                AVAudioSession.CategoryOptions.allowBluetooth.rawValue |
                AVAudioSession.CategoryOptions.defaultToSpeaker.rawValue
            try session.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.videoChat, options: AVAudioSession.CategoryOptions(rawValue: audioOptions))
            setupListenerBlocks()
            
            try session.setActive(true)
        } catch let err as NSError {
            print("Error setting up audio session \(err)")
        } catch {
            print("Error setting up audio session")
        }
    }
}

// MARK: - Audio Route functions
extension DefaultAudioDevice {
    fileprivate func setBluetoothAsPreferredInputDevice() {
        let btRoutes = [AVAudioSession.Port.bluetoothA2DP, AVAudioSession.Port.bluetoothLE, AVAudioSession.Port.bluetoothHFP]
        AVAudioSession.sharedInstance().availableInputs?.forEach({ el in
            if btRoutes.contains(el.portType) {
                do {
                    try AVAudioSession.sharedInstance().setPreferredInput(el)
                } catch {
                    print("Error setting BT as preferred input device")
                }
            }
        })
    }
    
    fileprivate func configureAudioSessionWithDesiredAudioRoute(desiredAudioRoute: String) {
        let session = AVAudioSession.sharedInstance()
        
        if desiredAudioRoute == DefaultAudioDevice.kAudioDeviceBluetooth {
            setBluetoothAsPreferredInputDevice()
        }
        do {
            if desiredAudioRoute == DefaultAudioDevice.kAudioDeviceSpeaker {
                try session.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
            } else {
                try session.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            }
        } catch let err as NSError {
            print("Error setting audio route: \(err)")
        }
    }
}

// MARK: - Render and Record C Callbacks
func renderCb(inRefCon:UnsafeMutableRawPointer,
              ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
              inTimeStamp:UnsafePointer<AudioTimeStamp>,
              inBusNumber:UInt32,
              inNumberFrames:UInt32,
              ioData:UnsafeMutablePointer<AudioBufferList>?) -> OSStatus
{
    let audioDevice: DefaultAudioDevice = Unmanaged.fromOpaque(inRefCon).takeUnretainedValue()
    if !audioDevice.playing { return 0 }
    
    let _ = audioDevice.deviceAudioBus!.readRenderData((ioData?.pointee.mBuffers.mData)!, numberOfSamples: inNumberFrames)
    updatePlayoutDelay(withAudioDevice: audioDevice)
    
    return noErr
}

func recordCb(inRefCon:UnsafeMutableRawPointer,
              ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
              inTimeStamp:UnsafePointer<AudioTimeStamp>,
              inBusNumber:UInt32,
              inNumberFrames:UInt32,
              ioData:UnsafeMutablePointer<AudioBufferList>?) -> OSStatus
{
    let audioDevice: DefaultAudioDevice = Unmanaged.fromOpaque(inRefCon).takeUnretainedValue()
    if audioDevice.bufferList == nil || inNumberFrames > audioDevice.bufferNumFrames {
        if audioDevice.bufferList != nil {
            audioDevice.bufferList!.pointee.mBuffers.mData?
                .assumingMemoryBound(to: UInt16.self).deallocate()
            audioDevice.bufferList?.deallocate()
        }
        
        audioDevice.bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        audioDevice.bufferList?.pointee.mNumberBuffers = 1
        audioDevice.bufferList?.pointee.mBuffers.mNumberChannels = 1
        
        audioDevice.bufferList?.pointee.mBuffers.mDataByteSize = inNumberFrames * UInt32(MemoryLayout<UInt16>.size)
        audioDevice.bufferList?.pointee.mBuffers.mData = UnsafeMutableRawPointer(UnsafeMutablePointer<UInt16>.allocate(capacity: Int(inNumberFrames)))
        audioDevice.bufferNumFrames = inNumberFrames
        audioDevice.bufferSize = (audioDevice.bufferList?.pointee.mBuffers.mDataByteSize)!
    }
    
    AudioUnitRender(audioDevice.recordingVoiceUnit!,
                    ioActionFlags,
                    inTimeStamp,
                    1,
                    inNumberFrames,
                    audioDevice.bufferList!)
    
    if audioDevice.recording {
        audioDevice.deviceAudioBus!.writeCaptureData((audioDevice.bufferList?.pointee.mBuffers.mData)!, numberOfSamples: inNumberFrames)
    }
    
    if audioDevice.bufferSize != audioDevice.bufferList?.pointee.mBuffers.mDataByteSize {
        audioDevice.bufferList?.pointee.mBuffers.mDataByteSize = audioDevice.bufferSize
    }
    
    updateRecordingDelay(withAudioDevice: audioDevice)
    
    return noErr
}

func updatePlayoutDelay(withAudioDevice audioDevice: DefaultAudioDevice) {
    audioDevice.playoutDelayMeasurementCounter += 1
    if audioDevice.playoutDelayMeasurementCounter >= 100 {
        // Update HW and OS delay every second, unlikely to change
        audioDevice.playoutDelay = 0
        let session = AVAudioSession.sharedInstance()
        
        // HW output latency
        let interval = session.outputLatency
        audioDevice.playoutDelay += UInt32(interval * DefaultAudioDevice.kToMicroSecond)
        // HW buffer duration
        let ioInterval = session.ioBufferDuration
        audioDevice.playoutDelay += UInt32(ioInterval * DefaultAudioDevice.kToMicroSecond)
        audioDevice.playoutDelay += UInt32(audioDevice.playoutAudioUnitPropertyLatency * DefaultAudioDevice.kToMicroSecond)
        // To ms
         audioDevice.playoutDelay = (audioDevice.playoutDelay - 500) / 1000

        audioDevice.playoutDelayMeasurementCounter = 0
    }
}

func updateRecordingDelay(withAudioDevice audioDevice: DefaultAudioDevice) {
    audioDevice.recordingDelayMeasurementCounter += 1
    
    if audioDevice.recordingDelayMeasurementCounter >= 100 {
        audioDevice.recordingDelay = 0
        let session = AVAudioSession.sharedInstance()
        let interval = session.inputLatency
        
        audioDevice.recordingDelay += UInt32(interval * DefaultAudioDevice.kToMicroSecond)
        let ioInterval = session.ioBufferDuration
        
        audioDevice.recordingDelay += UInt32(ioInterval * DefaultAudioDevice.kToMicroSecond)
        audioDevice.recordingDelay += UInt32(audioDevice.recordingAudioUnitPropertyLatency * DefaultAudioDevice.kToMicroSecond)
        
        audioDevice.recordingDelay = audioDevice.recordingDelay.advanced(by: -500) / 1000
        
        audioDevice.recordingDelayMeasurementCounter = 0
    }
}
