E2EE Basic Video Chat Sample App
===============================

The E2EE Basic-Video-Chat app is a very simple application meant to get a new developer
started using the OpenTok iOS SDK and end to end encryption.

Quick Start
-----------

To use this application:

1. Follow the instructions in the [Quick Start](../README.md#quick-start)
   section of the main README file for this repository.

   Among other things, you need to set values for the `kApiKey`, `kSessionId`,
   `kToken`, and `kEncryptionSecret` constants. See [Obtaining OpenTok
   Credentials](../README.md#obtaining-opentok-credentials)
   in the main README file for the repository.

2. To create an E2EE connection you must first enable this functionality server side.
   You enable end-to-end encryption when you create a session using the REST API. 
   Set the e2ee property to true. See the [E2EE](https://tokbox.com/developer/guides/end-to-end-encryption/#server_side) guide.

3. When you run the application, it connects to an OpenTok session and
   publishes an audio-video stream from your device to the session.

4. Run the app on a second client. You can do this by deploying the app to an
   iOS device and testing it in the simulator at the same time. Or you can use
   the browser_demo.html file to connect in a browser (see the following
   section).

   When the second client connects, it also publishes a stream to the session,
   and both clients subscribe to (view) each other’s stream.

Application Notes
-----------------

*   Follow the code from the `ViewController.viewDidLoad(_:)` method through
    to the OpenTok callbacks to see how streams are created and handled in
    the OpenTok iOS SDK.

*   By default, all delegate methods from classes in the OpenTok iOS SDK are
    invoked on the main queue. This means that you can directly modify the view
    hierarchy from inside the callback, without any asynchronous callouts.

*   When the main view loads, the ViewController calls the `OTSession.setEncryptionSecret(_:, error:)`
    method to set the encryption secret. Then the 
    `OTSession.initWithApiKey(_:, sessionId:,delegate:)` method to initialize
    a Session object. The app then calls the
    `OTSession.connectWithToken(_:, error:)` to connect to the session. The
    `OTSessionDelegate.sessionDidConnect(_:)` message is sent when the app
    connects to the OpenTok session.

*   The `doPublish()` method of the app initializes a publisher and passes it
    into the `OTSession.publish(_:,error:)` method. This publishes an
    audio-video stream to the session.

*   The `OTSessionDelegate.session(_:,streamCreated:)` message is sent when
    a new stream is created in the session. In response, the
    method calls `OTSubscriber(stream:,delegate:)`,
    passing in the OTStream object. This causes the app to subscribe to the
    stream.


Configuration Notes
-------------------

*   You can test in the iOS Simulator or on a supported iOS device. However, the
    XCode iOS Simulator does not provide access to the camera. When running in
    the iOS Simulator, an OTPublisher object uses a demo video instead of the
    camera.

[1]: https://tokbox.com/account/#/
[2]: https://tokbox.com/developer/sdks/server/
