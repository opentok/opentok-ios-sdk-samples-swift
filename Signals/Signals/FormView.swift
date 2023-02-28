//
//  SignalParameterView.swift
//  junk
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI

struct FormView {
    @EnvironmentObject private var sdk: VonageVideoSDK
    @Binding var signalType : String
    @Binding var signalData : String
    @Binding var retryAfterConnect : Bool
    @State private var isAllConnections = false
    @State private var selectedConnections = Set<String>()
    @Binding var oneClick : Bool
}

extension FormView: View {
    var body: some View {
        VStack(spacing:40) {
            
            VStack {
                Toggle("Signal all", isOn: $isAllConnections)
                if (isAllConnections == false) {
                    Text("Choose connections:")
                       
                    List(sdk.connections, id: \.connectionId, selection: $selectedConnections) { connection in
                        
                            Text(sdk.isMyConnection(connection) ? "...self" : connection.connectionId.lastTenCharacter())
                    }
                    .multilineTextAlignment(.leading)
                    .environment(\.editMode, .constant(EditMode.active))
                    
                }
            }
            
            HStack {
               
                    Text("Type:")
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
               
                    Text("Content:")
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
            
            Button(action: {
                self.oneClick.toggle()
                for c in selectedConnections {
                    sdk.sendSignalToConnection(connection: c, type: signalType, data: signalData)
                }
            }) {
                Text("Send")
            }
        }
        .padding()
    }
    
}

struct SignalParameterView_Previews: PreviewProvider {
    static var previews: some View {
        FormView(signalType: Binding.constant("Greeting"), signalData: Binding.constant("Hello"), retryAfterConnect: Binding.constant(false), oneClick: Binding.constant(false))

    }
}
