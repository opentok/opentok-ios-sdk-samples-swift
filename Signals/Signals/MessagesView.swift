//
//  SignalMessagesView.swift
//  junk
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI


struct SignalMessage: Identifiable {
    let id: Int
    var streamId: String
    var msg: String
}

struct MessagesView {
    @EnvironmentObject private var sdk: VonageVideoSDK
}

extension MessagesView: View {
    var body: some View {
        LazyVStack(alignment: .leading) {

            ForEach(sdk.messages) { m in
                    Spacer()
                    VStack(alignment: .leading) {
                        HStack {
                            if m.outgoing {
                                Image(systemName: "arrow.up.forward.square.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "arrow.down.left.square.fill")
                                    .foregroundColor(.brown)
                            }
                            Text(m.displayConnId)
                                .padding(.horizontal)
                                .multilineTextAlignment(.leading)
                                .font(.system(size: 12))
                            Spacer()
                            Text(m.type)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 12))
                              
                            
                        }
                        Spacer()
                        HStack {
                            Image(systemName: "arrow.up.forward.square.fill")
                                .foregroundColor(.green)
                                .hidden()
                            Text(m.content)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 14))
                                
                                .allowsTightening(true)
                                .lineLimit(1)
                        }

                    }
                    .padding(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .circular).stroke(Color(uiColor: .tertiaryLabel), lineWidth: 1)
                            .shadow(radius: 5)
                       
                            
                    )
                    
                }
                
         
            
        }
        .padding()
                        
       }
    
}

struct SignalMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MessagesView()
    }
}
