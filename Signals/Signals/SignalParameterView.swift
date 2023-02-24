//
//  SignalParameterView.swift
//  junk
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI

struct SignalParameterView {
    @Binding var signalType : String
    @Binding var signalData : String
    @Binding var retryAfterConnect : Bool
    @State private var isAllConnections = true
}

extension SignalParameterView: View {
    var body: some View {
        VStack(spacing:40) {
            ConnectionsView(isAllConnections: $isAllConnections)
            HStack {
               
                    Text("Signal type:")
                    Spacer()
                    TextField(signalType, text: $signalType)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                    //.font(Font.system(size: 20,design: .serif))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.black,lineWidth: 2))
                        .keyboardType(.asciiCapable)
                        .disableAutocorrection(true)
                        .lineLimit(1)
                    Spacer()

                }
            
           
            HStack {
               
                    Text("Signal content:")
                    Spacer()
                TextField("Hello world !!", text: $signalData, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                        .multilineTextAlignment(.center)
                    //.font(Font.system(size: 20,design: .serif))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.black,lineWidth: 2))
                        .keyboardType(.asciiCapable)
                        .disableAutocorrection(true)
                        .disableAutocorrection(true)
                        .lineLimit(2)
                    Spacer()
                }
            
          
            Toggle("Retry after reconnect:", isOn: $retryAfterConnect)
        }
        .padding()
    }
    
}

struct SignalParameterView_Previews: PreviewProvider {
    static var previews: some View {
        SignalParameterView(signalType: Binding.constant("Greeting"), signalData: Binding.constant("Hello"), retryAfterConnect: Binding.constant(false))
    }
}
