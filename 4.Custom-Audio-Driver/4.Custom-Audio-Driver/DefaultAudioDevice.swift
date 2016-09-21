//
//  DefaultAudioDevice.swift
//  4.Custom-Audio-Driver
//
//  Created by Roberto Perez Cubero on 21/09/2016.
//  Copyright © 2016 tokbox. All rights reserved.
//

import Foundation
import OpenTok

class DefaultAudioDevice: NSObject, OTAudioDevice {
#if (arch(i386) || arch(x86_64)) && os(iOS)
    static let kSampleRate: UInt16 = 44100
#else
    static let kSampleRate: UInt16 = 48000
#endif
    static let kOutputBus = AudioUnitElement(0)
    static let kInputBus = AudioUnitElement(1)
    
    var audioFormat = OTAudioFormat()
    let safetyQueue = DispatchQueue(label: "ot-audio-driver")

    var deviceAudioBus: OTAudioBus?
    
    func setAudioBus(_ audioBus: OTAudioBus) -> Bool {
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
    var recordingDelayHWAndOS: UInt32 = 0
    var recordingDelay: UInt32 = 0
    var recordingAudioUnitPropertyLatency: Float64 = 0
    var playoutDelay: UInt32 = 0
    var playing = false
    var recording = false
    var recordingRequested = false
    fileprivate var recordingVoiceUnit: AudioUnit?
    fileprivate var playoutVoiceUnit: AudioUnit?

    override init() {
        audioFormat.sampleRate = DefaultAudioDevice.kSampleRate
        audioFormat.numChannels = 1
    }
    
    deinit {
        
    }
    
    fileprivate func setupAudioUnit(withPlayout playout: Bool) -> Bool {
        var (audioUnit, bus, scope): (AudioUnit?, AudioUnitElement, AudioUnitScope) = {
            if playout {
                return (recordingVoiceUnit, DefaultAudioDevice.kOutputBus, kAudioUnitScope_Output)
            } else {
                return (playoutVoiceUnit, DefaultAudioDevice.kInputBus, kAudioUnitScope_Input)
            }
        }()
        
        let bytesPerSample = UInt32(MemoryLayout<Int16>.size)
        var streamFormat = AudioStreamBasicDescription()
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
        let result = AudioComponentInstanceNew(foundVpioUnitRef!, &audioUnit)
        
        // Check result
        
        var value = UnsafePointer<UInt32>(bitPattern: 1)
        AudioUnitSetProperty(audioUnit!, kAudioOutputUnitProperty_EnableIO, scope, bus, &value, UInt32(MemoryLayout<UInt32>.size))
        AudioUnitSetProperty(audioUnit!, kAudioUnitProperty_StreamFormat, scope, bus, &value, UInt32(MemoryLayout<UInt32>.size))
        
        if playout {
            setupPlayoutCallback()
        } else {
            setupRecordingCallback()
        }
        
        return true
    }
    
    fileprivate func setupPlayoutCallback() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        var renderCallback = AURenderCallbackStruct(inputProc: renderCb, inputProcRefCon: selfPointer)
        AudioUnitSetProperty(recordingVoiceUnit!,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             DefaultAudioDevice.kOutputBus,
                             &renderCallback,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
    }
    
    fileprivate func setupRecordingCallback() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        var inputCallback = AURenderCallbackStruct(inputProc: recordCb, inputProcRefCon: selfPointer)
        AudioUnitSetProperty(playoutVoiceUnit!,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Global,
                             DefaultAudioDevice.kInputBus,
                             &inputCallback,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        let value = UnsafePointer<UInt32>(bitPattern: 0)
        AudioUnitSetProperty(playoutVoiceUnit!,
                             kAudioUnitProperty_ShouldAllocateBuffer,
                             kAudioUnitScope_Output,
                             DefaultAudioDevice.kInputBus,
                             value,
                             UInt32(MemoryLayout<UInt32>.size))
    }
    
    fileprivate func tearDownAudio() {
        
    }
    
    fileprivate func freeupAudioBuffers() {
        
    }
    
    // MARK: - Audio Device Implementation
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
        return true
    }
    func isRendering() -> Bool {
        return playing
    }
    func isCapturing() -> Bool {
        return recording
    }
    func estimatedRenderDelay() -> UInt16 {
        return UInt16(playoutDelay)
    }
    func estimatedCaptureDelay() -> UInt16 {
        return UInt16(recordingDelay)
    }
    func captureIsAvailable() -> Bool {
        return true
    }
    func captureIsInitialized() -> Bool {
        return true
    }
    
    func initializeRendering() -> Bool {
        return !playing
    }
    
    func startRendering() -> Bool {
        if playing { return true }
        if playoutVoiceUnit == nil {
            playing = setupAudioUnit(withPlayout: true)
            if !playing {
                return false
            }
        }
        
        let result = AudioOutputUnitStart(playoutVoiceUnit!)
        
        if result != noErr {
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
            return false
        }
        
        if !recording && !recordingRequested {
            tearDownAudio()
        }
        
        return true
    }
    
    
    func initializeCapture() -> Bool {
        return !recording
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
        
        if !recording && !recordingRequested {
            tearDownAudio()
        }
        
        return true
    }
}

func updatePlayoutDelay(withAudioDevice audioDevice: DefaultAudioDevice) {
    audioDevice.playoutDelayMeasurementCounter += 1
    if audioDevice.playoutDelayMeasurementCounter >= 100 {
        // Update HW and OS delay every second, unlikely to change
        audioDevice.playoutDelay = 0
        let session = AVAudioSession.sharedInstance()
        
        // HW output latency
        let interval = session.outputLatency
        audioDevice.playoutDelay += UInt32(interval * 1000000)
        // HW buffer duration
        let ioInterval = session.ioBufferDuration
        audioDevice.playoutDelay += UInt32(ioInterval * 1000000)
        audioDevice.playoutDelay += UInt32(audioDevice.playoutAudioUnitPropertyLatency * 1000000)
        // To ms
        audioDevice.playoutDelay = (audioDevice.playoutDelay - 500) / 1000
        
        audioDevice.playoutDelayMeasurementCounter = 0
    }
}

func updateRecordingDelay(withAudioDevice audioDevice: DefaultAudioDevice) {
    audioDevice.recordingDelayMeasurementCounter += 1
    
    if audioDevice.recordingDelayMeasurementCounter >= 100 {
        audioDevice.recordingDelayHWAndOS = 0
        let session = AVAudioSession.sharedInstance()
        let interval = session.inputLatency
        
        audioDevice.recordingDelayHWAndOS += UInt32(interval * 1000000)
        let ioInterval = session.ioBufferDuration
        
        audioDevice.recordingDelayHWAndOS += UInt32(ioInterval * 1000000)
        audioDevice.recordingDelayHWAndOS += UInt32(audioDevice.recordingAudioUnitPropertyLatency * 1000000)
        
        audioDevice.recordingDelayHWAndOS = audioDevice.recordingDelayHWAndOS - 500 / 1000
        
        audioDevice.recordingDelayMeasurementCounter = 0
    }
    
    audioDevice.recordingDelay = audioDevice.recordingDelayHWAndOS
}

func renderCb(inRefCon:UnsafeMutableRawPointer,
              ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
              inTimeStamp:UnsafePointer<AudioTimeStamp>,
              inBusNumber:UInt32,
              inNumberFrames:UInt32,
              ioData:UnsafeMutablePointer<AudioBufferList>?) -> OSStatus
{
    let audioDevice: DefaultAudioDevice = Unmanaged.fromOpaque(inRefCon).takeUnretainedValue()
    if !audioDevice.playing { return 0 }
    
    let _ = audioDevice.deviceAudioBus!.readRenderData(ioData?.pointee.mBuffers.mData, numberOfSamples: inNumberFrames)
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
            free(audioDevice.bufferList!.pointee.mBuffers.mData)
            free(audioDevice.bufferList)
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
        audioDevice.deviceAudioBus!.writeCaptureData(audioDevice.bufferList?.pointee.mBuffers.mData, numberOfSamples: inNumberFrames)
    }
    
    if audioDevice.bufferSize != audioDevice.bufferList?.pointee.mBuffers.mDataByteSize {
        audioDevice.bufferList?.pointee.mBuffers.mDataByteSize = audioDevice.bufferSize
    }
    
    updateRecordingDelay(withAudioDevice: audioDevice)
    
    return noErr
}
