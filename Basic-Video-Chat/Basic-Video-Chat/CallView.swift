//
//  CallView.swift
//  Teleclinic
//
//  Created on 05/06/24.
//  Copyright © 2024 Teleclinic GmbH. All rights reserved.
//

import SwiftUI

struct CallView: View {

    @ObservedObject
    var viewModel: CallViewModel

    var onFinish: () -> Void

    private let idleTimerWasAlreadyDisabled = UIApplication.shared.isIdleTimerDisabled

    var body: some View {
        VStack(spacing: 0) {
            contentView
            footerView
        }
        .modifier(alertsModifier)
    }

    private var contentView: some View {
        ZStack {
            SubscribersView(subscribers: viewModel.subscribers)
                .ignoresSafeArea()

            PublisherView(publisher: viewModel.publisher)
                .padding(.bottom, viewModel.focusModeEnabled ? 40 : 18)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .overlay(alignment: .center) {
                    let status = viewModel.session?.sessionConnectionStatus
                    if viewModel.subscriberDisconnected {
                        ProgressView()
                            .scaleEffect(3)
                            .tint(.white)
                            .frame(width: 100, height: 100, alignment: .center)
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if status == .notConnected || status == .failed {
                        Text(Strings.videoCallConnectionClosed)
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding(16)
                    }
                }
#if DEBUGMENU
                .overlay(alignment: .top) {
                    CallDebugView(viewModel: viewModel)
                }
#endif
                .contentShape(Rectangle())
                .onTapGesture(perform: viewModel.toggleFocus)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !viewModel.focusModeEnabled {
                        FooterView(
                            isAudioEnabled: viewModel.isAudioEnabled,
                            isVideoEnabled: viewModel.isVideoEnabled,
                            flipCamera: viewModel.flipCamera,
                            toggleAudio: viewModel.toggleAudio,
                            toggleVideo: viewModel.toggleVideo,
                            hangUp: viewModel.promptFinishAlert
                        )
                    }
                }
                .ignoresSafeArea(.all, edges: .bottom)
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                stressButton
                Button("Stress Lifecycle") { viewModel.stressSessionLifecycle() }
                    .font(.footnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
            .zIndex(10)
        }
        .animation(.easeOut(duration: 0.5), value: viewModel.focusModeEnabled)
        .onAppear {
            viewModel.connect()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: viewModel.finished) { finished in
            if finished {
                onFinish()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = idleTimerWasAlreadyDisabled
        }
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            hangUpButton
            stayInCallButton
        }
    }

    private var alertsModifier: some ViewModifier {
        AlertsModifier(viewModel: viewModel)
    }

    private var hangUpButton: some View {
        Button(role: .none, action: viewModel.hangUp) {
            Text(Strings.videoCallViewHangUp)
        }
    }

    private var stayInCallButton: some View {
        Button(role: .cancel) {
            // no-op
        } label: {
            Text(Strings.videoCallStayInCall)
        }
    }

    private var stressButton: some View {
        Button("Stress AudioSession") {
            viewModel.stressAudioSession()
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(.primary)
        .allowsHitTesting(true)
    }
}

private struct AlertsModifier: ViewModifier {
    @ObservedObject var viewModel: CallViewModel

    func body(content: Content) -> some View {
        content
            .alert(Strings.generalGenericError, isPresented: $viewModel.presentErrorAlert) {
                Button(role: .none, action: viewModel.hangUp) { Text(Strings.videoCallViewHangUp) }
                Button(role: .cancel) {} label: { Text(Strings.videoCallStayInCall) }
            }
            .alert(Strings.videoCallViewEndCall, isPresented: $viewModel.presentFinishAlert) {
                Button(role: .none, action: viewModel.hangUp) { Text(Strings.generalYes) }
                Button(role: .cancel) {} label: { Text(Strings.generalNo) }
            }
    }
}
