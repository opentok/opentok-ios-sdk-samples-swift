Video Transformers
======================

The Video Transformers app is a very simple application created on top of Basic Video Chat meant to get a new developer started using Media Processor APIs on OpenTok iOS SDK. For a full description, see the [Video Transformers tutorial at the
OpenTok developer center](https://tokbox.com/developer/guides/vonage-media-processor/ios).

You can use pre-built transformers in the Vonage Media Processor library or create your own custom video transformer to apply to published video.

You can use the OTPublisherKit.videoTransformers properties to apply video transformers to a stream.

For video, you can apply the background blur video transformer included in the Vonage Media Library.
You can use the <a href="/developer/sdks/ios/reference/Classes/OTPublisherKit.html#//api/name/audioTransformers"><code>OTPublisherKit.audioTransformers</code></a> and
<a href="/developer/sdks/ios/reference/Classes/OTPublisherKit.html#//api/name/videoTransformers"><code>OTPublisherKit.videoTransformers</code></a>
properties to apply audio and video transformers to a stream.

<p class="important">
  <b>Important:</b> The audio and video transformer API is a beta feature.
</p>

For video, you can apply the background blur video transformer included in the Vonage Media Library.

You can also create your own custom audio and video transformers.

## Applying a video transformer from the Vonage Media Library

Use the <a href="/developer/sdks/ios/reference/Classes/OTVideoTransformer.html#//api/name/initWithName:properties:"><code>[OTVideoTransformer initWithName:properties:]</code></a>
method to create a video transformer that uses a named transformer from the Vonage Media Library.

Currently, only one transformer is supported: background blur. Set the `name` parameter to `"BackgroundBlur"`.
Set the `properties` parameter to a JSON string defining properties for the transformer.
For the background blur transformer, this JSON includes one property -- `radius` -- which can be set
to `"High"`, `"Low"`, or `"None"`.

```swift
guard let backgroundBlur = OTVideoTransformer(name: "BackgroundBlur", properties: "{\"radius\":\"High\"}") else { return }

var myVideoTransformers = [OTVideoTransformer]()
myVideoTransformers.append(backgroundBlur)

// Set video transformers to publisher video stream
publisher.videoTransformers = myVideoTransformers
```

## Creating a custom video transformer

Create a class that implements the <a href="/developer/sdks/ios/reference/Protocols/OTCustomVideoTransformer.html"><code>OTCustomVideoTransformer</code></a> 
protocol. Implement the `[OTCustomVideoTransformer transform:]` method, applying a transformation to the `OTVideoFrame` object passed into the method. The `[OTCustomVideoTransformer transform:]` method is triggered for each video frame:

```swift
class CustomTransformer: NSObject, OTCustomVideoTransformer {    
    func transform(_ videoFrame: OTVideoFrame) {
        // Your custom transformation
    }
}
```

In this sample, to display one of the infinite transformations that can be applied to video frames, a logo is being added to the bottom right corner of the video.

```swift
class CustomTransformer: NSObject, OTCustomVideoTransformer {
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    func transform(_ videoFrame: OTVideoFrame) {
        if let image = UIImage(named: "Vonage_Logo.png") {
            let yPlaneData = videoFrame.getPlaneBinaryData(0)
            let videoWidth = Int(videoFrame.format?.imageWidth ?? 0)
            let videoHeight = Int(videoFrame.format?.imageHeight ?? 0)
            
            // Calculate the desired size of the image
            let desiredWidth = CGFloat(videoWidth) / 8 // Adjust this value as needed
            let desiredHeight = image.size.height * (desiredWidth / image.size.width)
            
            // Resize the image to the desired size
            if let resizedImage = resizeImage(image, to: CGSize(width: desiredWidth, height: desiredHeight)) {
                let yPlane = yPlaneData
                
                // Create a CGContext from the Y plane
                guard let context = CGContext(data: yPlane,
                                              width: videoWidth,
                                              height: videoHeight,
                                              bitsPerComponent: 8,
                                              bytesPerRow: videoWidth,
                                              space: CGColorSpaceCreateDeviceGray(),
                                              bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                    return
                }
                
                // Location of the image (in this case right bottom corner)
                let x = CGFloat(videoWidth) * 4/5
                let y = CGFloat(videoHeight) * 1/5
                
                // Draw the resized image on top of the Y plane
                let rect = CGRect(x: x, y: y, width: desiredWidth, height: desiredHeight)
                context.draw(resizedImage.cgImage!, in: rect)
            }
        }
    }
}
``` 

Then set the `OTPublisherKit.videoTransformers` property to an array that includes the object that implements the
OTCustomVideoTransformer interface:

```swift 
// Create an instance of CustomTransformer
var logoTransformer: CustomTransformer = CustomTransformer()

...

// Create custom transformer
guard let myCustomTransformer = OTVideoTransformer(name: "logo", transformer: logoTransformer)  else { return }

var myVideoTransformers = [OTVideoTransformer]()
myVideoTransformers.append(myCustomTransformer)

// Set video transformers to publisher video stream
publisher.videoTransformers = myVideoTransformers
```

You can combine the Vonage Media library transformer (see the previous section) with custom transformers or apply
multiple custom transformers by adding multiple PublisherKit.VideoTransformer objects to the ArrayList used
for the `OTPublisherKit.videoTransformers` property.

## Clearing video transformers for a publisher

To clear video transformers for a publisher, set the `OTPublisherKit.videoTransformers` property to an empty array.

```objectivec
publisher.videoTransformers = []
```

Adding the OpenTok library
==========================
In this example the OpenTok iOS SDK was not included as a dependency,
you can do it through Swift Package Manager or Cocoapods.


Swift Package Manager
---------------------
To add a package dependency to your Xcode project, you should select 
*File* > *Swift Packages* > *Add Package Dependency* and enter the repository URL:
`https://github.com/opentok/vonage-client-sdk-video.git`.


Cocoapods
---------
To use CocoaPods to add the OpenTok library and its dependencies into this sample app
simply open Terminal, navigate to the root directory of the project and run: `pod install`.


The Video-Transformers app is a very simple application meant to get a new developer
started using the OpenTok iOS SDK.