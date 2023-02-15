//
//  SendSignalButtonView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct SendSignalButtonView {
    @Binding var enterData : Bool
}
extension SendSignalButtonView: View {
    var body: some View {
        
        VStack {
            Button("Hello !!") {
                
            }
            .foregroundColor(Color.white)
            .background(Color.black)
            .cornerRadius(8)
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
                    // send signal
                })
        }
    }
}


struct SendSignalButtonView_Previews: PreviewProvider {
    static var previews: some View {
        SendSignalButtonView(enterData: Binding.constant(true))
    }
}
