//
//  SignalParameterView.swift
//  junk
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI

let m = ["a","b"]
struct FormView {
    @EnvironmentObject private var sdk: VonageVideoSDK
    @Binding var signalType : String
    @Binding var signalData : String
    @Binding var retryAfterConnect : Bool
    @State private var isAllConnections = false
    @State private var selectedConns = Set<String>()
    @Binding var oneClick : Bool
}

extension FormView: View {
    var body: some View {
        VStack(spacing:40) {
            
            VStack {
                Toggle("Signal all", isOn: $isAllConnections)
                if (isAllConnections == false) {
                    Text("Choose connections:")
                     
                       
                    List(sdk.connections, id: \.displayName, selection: $selectedConns) { c in
                        Text(c.displayName)
                    }
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 12))
                    .environment(\.editMode, .constant(EditMode.active))
                    .listStyle(PlainListStyle())
                    .lineLimit(2)
                    .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .circular).stroke(Color(uiColor: .tertiaryLabel), lineWidth: 2)
                                    )

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
                        .lineLimit(1)
                    Spacer()
                }
            
          
            Toggle("Retry after reconnect:", isOn: $retryAfterConnect)
            
            Button(action: {
                self.oneClick.toggle()
                for connId in selectedConns {
                    sdk.sendSignalToConnection(connection: connId, type: signalType, data: signalData)
                }
            }) {
                Text("Send")
            }
        }
        .padding(1)
        
    }
    
}

struct SignalParameterView_Previews: PreviewProvider {
    static var previews: some View {
        FormView(signalType: Binding.constant("Greeting"), signalData: Binding.constant("Hello"), retryAfterConnect: Binding.constant(false), oneClick: Binding.constant(false))
            .environmentObject(VonageVideoSDK())

    }
    
}
