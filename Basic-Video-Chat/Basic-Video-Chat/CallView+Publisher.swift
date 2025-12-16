//
//  CallView+Publisher.swift
//  Teleclinic
//
//  Created on 11/07/24.
//  Copyright © 2025 Teleclinic GmbH. All rights reserved.
//

import OpenTok
import SwiftUI

extension CallView {
    struct PublisherView: View {
        var publisher: OTPublisher?

        var body: some View {
            Color.gray
                .frame(width: 90, height: 120)
                .overlay {
                    if let publisher, let uiView = publisher.view {
                        VonageWrapperView(uiView: uiView)
                            .id(publisher.stream?.streamId)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
