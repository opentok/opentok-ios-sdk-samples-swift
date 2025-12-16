//
//  CallView+Footer.swift
//  Teleclinic
//
//  Created on 11/07/24.
//  Copyright © 2025 Teleclinic GmbH. All rights reserved.
//

import SwiftUI

extension CallView {
    struct FooterView: View {
        var isAudioEnabled: Bool
        var isVideoEnabled: Bool
        var flipCamera: () -> Void
        var toggleAudio: () -> Void
        var toggleVideo: () -> Void
        var hangUp: () -> Void

        var body: some View {
            HStack(spacing: 0) {
                Button(action: toggleVideo) {
                    Image(uiImage: toggleVideoImage)
                        .frame(maxWidth: .infinity)
                }
                Button(action: toggleAudio) {
                    Image(uiImage: toggleAudioImage)
                        .frame(maxWidth: .infinity)
                }
                Button(action: flipCamera) {
                    Image(uiImage: Images.VonageCall.flipCamFront.image)
                        .frame(maxWidth: .infinity)
                }
                Button(action: hangUp) {
                    Image(uiImage: Images.VonageCall.hangUp.image)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 40)
            .padding(.top, 24)
            .background(Colors.Content.primary.swiftUIColor.opacity(0.8))
            .clipShape(.rect(
                topLeadingRadius: 32,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 32
            ))
            .symbolRenderingMode(.monochrome) // ensure SF Symbols render as a single color
            .tint(.white) // make all control images/buttons white
        }
    }
}

private extension CallView.FooterView {

    var toggleAudioImage: UIImage {
        isAudioEnabled ? Images.VonageCall.micOn.image : Images.VonageCall.micOff.image
    }

    var toggleVideoImage: UIImage {
        isVideoEnabled ? Images.VonageCall.videoOn.image : Images.VonageCall.videoOff.image
    }

}

// Dummy assets and colors to fix build errors when design system is unavailable.
private struct DummyAsset {
    let image: UIImage
    init(systemName: String) {
        self.image = UIImage(systemName: systemName) ?? UIImage()
    }
}

private struct BrandColor {
    let swiftUIColor: Color
    init(_ color: Color) { self.swiftUIColor = color }
}

private enum Images {
    enum VonageCall {
        static let flipCamFront = DummyAsset(systemName: "camera.rotate")
        static let hangUp = DummyAsset(systemName: "phone.down.fill")
        static let micOn = DummyAsset(systemName: "mic.fill")
        static let micOff = DummyAsset(systemName: "mic.slash.fill")
        static let videoOn = DummyAsset(systemName: "video.fill")
        static let videoOff = DummyAsset(systemName: "video.slash.fill")
    }
}

private enum Colors {
    enum Content {
        static let primary = BrandColor(Color.black)
    }
}
