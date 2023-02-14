//
//  SendSignalButtonView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct SendSignalButtonView {
    @State var flag = false
}
extension SendSignalButtonView: View {
    var body: some View {
        ZStack {
            VStack {
                Button(" SIGNAL ") {
                    
                }
                .foregroundColor(Color.white)
                .background(Color.green)
                .cornerRadius(8)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .shadow(radius: 20)
                .simultaneousGesture(
                    LongPressGesture()
                        .onEnded {_ in
                            flag = true
                        })
                .highPriorityGesture(TapGesture()
                    .onEnded { _ in
                       // send signal
                    })
            }
            if flag {
                Color.gray.opacity(1.0).edgesIgnoringSafeArea(.all)
                VStack {
                      SignalParameterView()
                      Button(action: {
                          self.flag.toggle()
                      }) {
                          Text("Close")
                      }
                  }
                .background(Color.primary.colorInvert()).cornerRadius(10)

                      }
                  }
            
        }
    }


struct SendSignalButtonView_Previews: PreviewProvider {
    static var previews: some View {
        SendSignalButtonView()
    }
}
