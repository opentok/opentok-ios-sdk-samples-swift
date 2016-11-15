#!/bin/sh

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -list 
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 1.Hello-World -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 2.Custom-Video-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 3.Custom-Audio-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 4.Screen-Sharing -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 5.Live-Photo-Capture -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 6.Simple-Multiparty -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

