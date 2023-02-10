//
//  SignalParameterView.swift
//  junk
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI

struct SignalParameterView {
    @State private var dataType = ""
    @State private var retryAfterConnect = false
    @State private var isAllConnections = true
}

extension SignalParameterView: View {
    var body: some View {
        VStack(spacing:25) {
            ConnectionsView(isAllConnections: $isAllConnections)
            let gridItems = [GridItem()]
            HStack {
               
                    Text("Signal type:")
                    Spacer()
                    TextField("Greetings", text: $dataType)
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
                TextField("Hello world !!", text: $dataType, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                        .multilineTextAlignment(.center)
                    //.font(Font.system(size: 20,design: .serif))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.black,lineWidth: 2))
                        .keyboardType(.asciiCapable)
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
        SignalParameterView()
    }
}
