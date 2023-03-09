//
//  FormView.swift
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
    @State private var selectedConns = Set<String>()
    @Binding var oneClick : Bool
    @State private var signalCharError = false
}

extension FormView: View {
    var body: some View {
        VStack(spacing:40) {
            
            VStack {
                Toggle("Signal all", isOn: $isAllConnections)
                if (isAllConnections == false) {
                    HStack {
                        Text("Choose connections:")
                        Spacer()
                    }
                
                    List(sdk.connsInfo, id: \.displayName, selection: $selectedConns) { c in
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
                    TextField(signalType, text: $signalType, axis: .vertical)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .border(.gray, width: 1)
                        .keyboardType(.asciiCapable)
                        .disableAutocorrection(true)
                        .lineLimit(1)
                    Spacer()

                }
            
           
            HStack {
               
                    Text("Content:")
                    Spacer()
                    TextField("Hello world", text: $signalData, axis: .vertical)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                            .border(.gray, width: 1)
                            .keyboardType(.asciiCapable)
                            .disableAutocorrection(true)
                            .lineLimit(1)
                    Spacer()
                }
            
          
            Toggle("Retry after reconnect:", isOn: $retryAfterConnect)
            HStack {
                Spacer()
                Button(action: {
                    if signalData.isValidSignal() == false || signalType.isValidSignal() == false {
                        signalCharError = true
                    } else {
                        self.oneClick.toggle()
                        for connId in selectedConns {
                            sdk.sendSignalToConnection(connection: connId, type: signalType, data: signalData, retryAfterConnect: retryAfterConnect)
                        }
                    }
             
                }) {
                    Text("Send")
                }
                Spacer()
                Button(role: .cancel, action: {
                    self.oneClick.toggle()
                }) {
                    Text("Cancel")
                }
                Spacer()
            }

        }
        .padding(1)
        .alert("Only \"a-zA-Z0-9-_~\" and Space characters allowed for content and type.", isPresented: $signalCharError) {
                    Button("OK", role: .cancel) { }
            }
        
    }
    
}

struct FormView_Previews: PreviewProvider {
    static var previews: some View {
        FormView(signalType: Binding.constant("Greeting"), signalData: Binding.constant("Hello"), retryAfterConnect: Binding.constant(true), oneClick: Binding.constant(false))
            .environmentObject(VonageVideoSDK())

    }
    
}
