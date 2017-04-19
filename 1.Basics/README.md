Project 1: Basics
======================

The Basics app is a very simple application meant to get a new developer
started using the OpenTok iOS SDK.

Application Notes
-----------------

*   Follow the code from the `ViewController.viewDidLoad(_:)` method through
    to the OpenTok callbacks to see how streams are created and handled in
    the OpenTok iOS SDK.

*   In the VideoController.swift file, set values for the `kApiKey`, `kSessionId`,
    and `kToken` constants. For testing, you can obtain these values at your
    [OpenTok account page][1]. In a production application, use one of the
    [OpenTok server SDKs][2] to generate session IDs and tokens.

*   By default, all delegate methods from classes in the OpenTok iOS SDK are
    invoked on the main queue. This means that you can directly modify the view
    hierarchy from inside the callback, without any asynchronous callouts.

*   When the main view loads, the ViewController calls the
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

*   Use the browser-demo.html file (in located in the root directory of this
    project), to connect to the OpenTok session and publish an audio-video
    stream from a web browser:

    * Edit browser-demo.html file and modify the variables `apiKey`,
      `sessionId`, and `token` with your OpenTok API Key, and with the matching
      session ID and token. (Note that you would normally use the OpenTok
      server-side libraries to issue unique tokens to each client in a session.
      But for testing purposes, you can use the same token on both clients.
      Also, depending on your app, you may use the OpenTok server-side
      libraries to generate new sessions.)

    * Add the browser_demo.html file to a web server. (You cannot run WebRTC
      video in web pages loaded from the desktop.)

    * In a browser, load the browser_demo.html file from the web server. Click
      the Connect and Publish buttons. Run the app on your iOS device to send
      and receive streams between the device and the browser.


Configuration Notes
-------------------

*   You can test in the iOS Simulator or on a supported iOS device. However, the
    XCode iOS Simulator does not provide access to the camera. When running in
    the iOS Simulator, an OTPublisher object uses a demo video instead of the
    camera.

[1]: https://tokbox.com/account/#/
[2]: https://tokbox.com/developer/sdks/server/
