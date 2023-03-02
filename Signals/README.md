Signaling Sample App
===============================

The Signaling app is a very simple application meant to get a new developer
started using the signaling features of OpenTok iOS SDK.

Quick Start
-----------

To use this application:

1. Follow the instructions in the [Quick Start](../README.md#quick-start)
   section of the main README file for this repository.

   Among other things, you need to set values for the `kApiKey`, `kSessionId`,
   and `kToken` constants. See [Obtaining OpenTok
   Credentials](../README.md#obtaining-opentok-credentials)
   in the main README file for the repository.

2. When you run the application, an OpenTok session is created . Signaling only needs
   OTConnection(s).

3. Run the app on a second client. You can do this by deploying the app to an
   iOS device and testing it in the simulator at the same time. 

   
Application Notes
-----------------

*   Signals are meant to transmit basic text data between participants in a session.
*   Signals don't have extensive chat like features (like emoji's etc). 

*   Sending an signal using an session object as follows:
```swift
 session.signal(withType: type , string: data, connection:c.getOTConnection(), error: nil)
 ```
 or 
 ```swift
 session.signal(withType: type , string: data, connection:c.getOTConnection(), retryAfterReconnect: retryAfterConnect, error: nil)
 ```
 `retryAfterReconnect` default value is `true` in the first call. The error case fails silently.

 *  Receiving a signal is done using OTSessionDelegate callback as follows:
 ```swift
 func session(_ session: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
    ..
 }
 ```
You just need to implement the above calls in your app. 

* Valid Characters in a signal data  is limited  to `[^a-zA-Z0-9-_~\\s]`. If a non valid character is used , signal is  not send. To get around this you can encode signal data with `base64` and decode it on other side. This way you can send emoji's for example. A sample code which extends `String` is provided below for reference:
```swift
extension String {
    func fromBase64() -> String? {
            guard let data = Data(base64Encoded: self) else {
                return nil
            }

            return String(data: data, encoding: .ascii)
        }

        func toBase64() -> String {
            return Data(self.utf8).base64EncodedString()
        }
        func isValidSignal() -> Bool {
            return self.count <= 128 && self.range(of: "[^a-zA-Z0-9-_~\\s]", options: .regularExpression) == nil
        }
 ...
 }       
```

Screen shot (SwiftUI based)
-----------------

Starting screen 

Starting screen with Messages

Signal Form view