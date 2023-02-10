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

struct SignalMessagesView {
    @State private var messages = [
        SignalMessage(id: 1, streamId: "..7459", msg: "This is a message"),
        SignalMessage(id: 2, streamId: "..7478", msg: "This is a message This is a message, This is a message, 92749 , This is a message "),
        SignalMessage(id: 3, streamId: "..7478", msg: "This is a message"),
        SignalMessage(id: 3, streamId: "..1234", msg: "This is a message"),
        SignalMessage(id: 3, streamId: "..4567", msg: "This is a message")
    ]
}
extension SignalMessagesView: View {
    var body: some View {
        LazyVStack(alignment: .leading) {
            Section("Messages")
            {
                ForEach(messages) { message in
                    Spacer()
                    HStack {
                        /*@START_MENU_TOKEN@*/Text(message.streamId)/*@END_MENU_TOKEN@*/
                            .padding(.horizontal)
                        Spacer()
                        
                        Text(message.msg)
                            .padding(.horizontal)
                            .multilineTextAlignment(.trailing)
                            .allowsTightening(true)
                            .lineLimit(2)
                    }
                    Spacer()
                    
                }
                
            }
            
        }
        .padding()
       }
    
}

struct SignalMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        SignalMessagesView()
    }
}
