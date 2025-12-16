//
//  CallView+Subscribers.swift
//  Teleclinic
//
//  Created on 11/07/24.
//  Copyright © 2025 Teleclinic GmbH. All rights reserved.
//

import OpenTok
import SwiftUI

extension CallView {
    struct SubscribersView: View {
        var subscribers: [OTSubscriber]

        var body: some View {
            Color.black
                .overlay {
                    VStack(spacing: 0) {
                        ForEach(subscribers, id: \.stream?.streamId) { subscriber in
                            Color.black
                                .overlay {
                                    if let uiView = subscriber.view {
                                        VonageWrapperView(uiView: uiView)
                                    }
                                }
                        }
                    }
                }
        }
    }
}
