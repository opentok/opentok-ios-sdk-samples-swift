Screen Sharing Sample App
=========================

This project shows how to use OpenTok iOS SDK to publish a stream that uses a
UIView, instead of a camera, as the video source.

See the "Custom Video Driver" sample code for basic information on using a
custom video capturer.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

The main storyboard includes a UITextView object that is referenced in the
ViewController.swift file as the `timeDisplay` property. The `viewDidLoad` method
(in  ViewController.swift) sets up a timer that updates this text field periodically
to display the Date timestamp. This example will use this text field's view as
the video source for the published stream.

videoFrame = OTVideoFrame(format:format)


Upon connecting to the OpenTok session, the app instantiates an OTPublisherKit
object, and calls its `setCapturer()` method to set a custom video capturer.
This custom video capturer is defined by the ScreenCapture class:

    func doPublish() {
        defer {
            process(error: error)
        }
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        publisher = OTPublisher(delegate: self, settings: settings)
        publisher?.videoType = .screen
        publisher?.audioFallbackEnabled = false
        
        capturer = ScreenCapturer(withView: view)
        publisher?.videoCapture = capturer!.videoCapture()
        
        var error: OTError? = nil
        session.publish(publisher!, error: &error)
    }

Note that the call to the `OTPublisher.videoType` method sets the
video type of the published stream to `OTPublisherKitVideoTypeScreen`. This
optimizes the video encoding for screen sharing. It is recommended to use a low
frame rate (5 frames per second or lower) with this video type. When using the
screen video type in a session that uses the [OpenTok Media
Server](https://tokbox.com/opentok/tutorials/create-session/#media-mode), the
audio-only fallback feature is disabled, so that the video does not drop out in
subscribers. (However, the publisher in this sample does not publish audio.)

The code instantiates a ScreenCapture object and passes it into the
`publisher.videoCapture` method. This sets the custom video capturer for
the publisher The ScreenCapture class implements the OTVideoCapture protocol,
defined in the OpenTok iOS SDK.

The implementation of the `OTVideoCapture.initCapture()` method sets up a timer
that periodically gets a UIImage based on a screenshot of the main view
(`self.view`):

	let screen = self.screenShoot()
	let padded = self.resizeAndPad(image: screen)
	self.consume(frame: padded)

The `screenshot()` method simply returns a UIImage representation of
`self.view`.

The `viewDidLoad` method initialized a OTVideoFormat and OTVideoFrame object to
be used by the custom video capturer:

    let format = OTVideoFormat()
    format.pixelFormat = .argb

The `consumeFrame()` method sets up properties of the current video frame:

	let timeStamp = mach_absolute_time()
	let time = CMTime(seconds: Double(timeStamp), preferredTimescale: 1000)
	let ref = pixelBuffer(fromCGImage: frame)
        
	CVPixelBufferLockBaseAddress(ref, CVPixelBufferLockFlags(rawValue: 0))
        
	videoFrame?.timestamp = time
	videoFrame?.format.estimatedCaptureDelay = 100
	videoFrame?.orientation = .up
        
	videoFrame?.clearPlanes()
	videoFrame?.planes.addPointer(CVPixelBufferGetBaseAddress(ref))
	videoCaptureConsumer.consumeFrame(videoFrame)

The `consumeFrame()` method then calls the
`self.videoCaptureConsumer.consumeFrame(videoFrame)` method:

    videoCaptureConsumer.consumeFrame(videoFrame)

The `videoCaptureConsumer` property of the OTVideoCapturer object is defined by
the OTVideoCaptureConsumer protocol. Its `consumeFrame()` method sets a video
frame to be published by the OTPublisherKit object.
