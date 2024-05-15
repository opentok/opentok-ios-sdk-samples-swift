Picture In Picture Sample App
==================================

This project uses the custom video render features in the OpenTok iOS SDK.
By the end of a code review, you should have a basic understanding how to implement
Picture-In-Picture for the subscribed stream.

Note that this sample application is not supported in the XCode iOS Simulator
because the Picture-In-Picture only works on real device.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.


### ExampleVideoRender

OTSubscriber needs an instance supporting the
`OTVideoRender` protocol to display video contents. In short, the instance
ID that is set to the `videoRender` property will receive YUV frames (I420) 
as they are received (subscriber).

In this example we get the YUV frames from `videoRender`,
and convert the frames to CMSampleBuffer.
Refer to function `createSampleBufferWithVideoFrame` for YUV frames to CMSampeBuffer conversion.

Then, draw the video stream on the PIP by adding the CMSampleBuffer into PIP 
`sampleBufferDisplayLayer`


### ViewController

Setup a PIP controller is well documented in [apple doc][1]. 

To see sample in action, you need to add a publisher (which will display as a subscriber), either run the app a second time in an iOS device or use the OpenTok Playground to connect to the session in a supported web browser (Chrome, Firefox, or Internet Explorer 10-11).


[1]: https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-for-video-calls
