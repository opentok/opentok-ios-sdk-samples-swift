#!/bin/sh

set -e

cd Basic-Video-Chat/
pod install
xcodebuild -workspace Basic-Video-Chat.xcworkspace  -scheme Basic-Video-Chat -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

cd ../Custom-Video-Driver/
pod install
xcodebuild -workspace Custom-Video-Driver.xcworkspace  -scheme Custom-Video-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

cd ../Custom-Audio-Driver/
pod install
xcodebuild -workspace Custom-Audio-Driver.xcworkspace  -scheme Custom-Audio-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

cd ../Screen-Sharing/
pod install
xcodebuild -workspace Screen-Sharing.xcworkspace  -scheme Screen-Sharing -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

cd ../Live-Photo-Capture/
pod install
xcodebuild -workspace Live-Photo-Capture.xcworkspace  -scheme Live-Photo-Capture -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

cd ../Simple-Multiparty/
pod install
xcodebuild -workspace Simple-Multiparty.xcworkspace  -scheme Simple-Multiparty -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

cd ../Multiparty-UICollectionView/
xcodebuild -workspace Multiparty-UICollectionView.xcworkspace  -scheme Multiparty-UICollectionView -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
