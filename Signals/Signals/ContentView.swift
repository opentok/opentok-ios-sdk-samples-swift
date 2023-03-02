//
//  ContentView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct ContentView {
    @State var oneClick = true
    @StateObject  private var sdk = VonageVideoSDK()
    @State private var signalType = "Greetings"
    @State private var signalData = "Hello World"
    @State private var isRetryOnReconnect = true
    
}
extension ContentView: View {
    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: 25) {
                if (sdk.isSessionConnected == false) {
                    Text("Connecting ...")
                        .font(.title)
                } else {
                    if oneClick == true {
                        Button("Hello !!") {
                            sdk.sendSignalToAll(type: "Greetings", data: "Hello World")
                        }
                        .font(.title)
 
                        //OneClickView(oneClick: $oneClick)
                        Button {
                            oneClick = false
                           // print("Edit button was tapped")
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        ScrollView {
                            MessagesView()
                            
                        }
                    }
                    else  {
                        VStack {
                            FormView(signalType: $signalType, signalData: $signalData, retryAfterConnect: $isRetryOnReconnect, oneClick: $oneClick)
                        }
                    }
                }

                
            }
            .padding(30)
            .environmentObject(sdk)
            .onDisappear {
                sdk.closeAll()
            }
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



            
