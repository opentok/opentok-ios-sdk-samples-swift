//
//  SendSignalButtonView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct OneClickView {
    @Binding var oneClick : Bool
    @EnvironmentObject private var sdk: VonageVideoSDK
}
extension OneClickView: View {
    var body: some View {
        
        VStack {

            
            Button("Hello !!!") {
                // action below in TapGesture
            }
            .simultaneousGesture(
                LongPressGesture()
                    .onEnded {_ in
                        oneClick = false
                    })
            .highPriorityGesture(TapGesture()
                .onEnded { _ in
                    sdk.sendSignalToAll(type: "Greetings", data: "Hello World")
                })
        }
    }
}


struct SendSignalButtonView_Previews: PreviewProvider {
    static var previews: some View {
        OneClickView(oneClick: Binding.constant(true))
    }
}
