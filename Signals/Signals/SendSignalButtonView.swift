//
//  SendSignalButtonView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct SendSignalButtonView {
    @Binding var enterData : Bool
    @EnvironmentObject var vonageVideo: VonageVideo
}
extension SendSignalButtonView: View {
    var body: some View {
        
        VStack {
            Button("Signal") {
                // action below in TapGesture
            }
            .foregroundColor(Color.white)
            .background(Color.black)
            .font(.largeTitle)
            .fontWeight(.heavy)
            .shadow(radius: 20)
            .simultaneousGesture(
                LongPressGesture()
                    .onEnded {_ in
                        enterData = true
                    })
            .highPriorityGesture(TapGesture()
                .onEnded { _ in
                    vonageVideo.sendSignalToAll(type: nil, data: nil)
                })
        }
    }
}


struct SendSignalButtonView_Previews: PreviewProvider {
    static var previews: some View {
        SendSignalButtonView(enterData: Binding.constant(true))
    }
}
