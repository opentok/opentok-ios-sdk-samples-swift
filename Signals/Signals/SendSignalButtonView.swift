//
//  SendSignalButtonView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct SendSignalButtonView {
    
}
extension SendSignalButtonView: View {
    var body: some View {
        HStack{
            Spacer()
            Button(" SEND SIGNAL ") {
                
            }
            .foregroundColor(Color.white)
            .background(Color.green)
            .cornerRadius(8)
            .font(.largeTitle)
            .fontWeight(.heavy)
            .shadow(radius: 20)
            Spacer()
        }
    }
}

struct SendSignalButtonView_Previews: PreviewProvider {
    static var previews: some View {
        SendSignalButtonView()
    }
}
