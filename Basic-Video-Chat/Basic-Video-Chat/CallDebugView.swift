//
//  CallDebugView.swift
//  Teleclinic
//
//  Created on 16.10.25.
//  Copyright © 2025 Teleclinic GmbH. All rights reserved.
//

#if DEBUGMENU

import OpenTok
import SwiftUI

struct CallDebugView: View {

    @ObservedObject
    var viewModel: CallViewModel

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollViewReader { proxy in
                ScrollView {
                    content
                        .id("content")
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollDown(proxy)
                    }
                }
                .onChange(of: viewModel.debugLogMessages.count) { _ in
                    scrollDown(proxy)
                }
            }
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.4))
    }

    @ViewBuilder
    private var content: some View {
        if let session = viewModel.session {
            VStack(alignment: .leading) {
                Text("Session status: \(session.sessionConnectionStatus.debugDescription)")
                Text("Session streams: \(session.streams.count)")
                ForEach(session.streams.values.map { $0.streamId }.sorted(), id: \.self) { streamId in
                    Text("- stream: \(streamId)")
                }
                if let publisher = viewModel.publisher {
                    Text("Publisher stream: \(publisher.stream?.streamId ?? "-")")
                }
                ForEach(viewModel.subscribers, id: \.stream?.streamId) { subscriber in
                    Text("Subscriber stream: \(subscriber.stream?.streamId ?? "-")")
                }
                Text(viewModel.debugLogMessages.joined(separator: "\n"))
            }
            .font(.bodyXxsRegular)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("content", anchor: .bottom)
        }
    }

}

private extension OTSessionConnectionStatus {

    var debugDescription: String {
        switch self {
        case .notConnected: "notConnected"
        case .connected: "connected"
        case .connecting: "connecting"
        case .reconnecting: "reconnecting"
        case .disconnecting: "disconnecting"
        case .failed: "failed"
        @unknown default: "unknown"
        }
    }

}

#endif
