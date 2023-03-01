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
            VStack(alignment: .center) {
                if (sdk.isSessionConnected == false) {
                    Text("Connecting to session ...")
                } else {
                    if oneClick == true {
                        OneClickView(oneClick: $oneClick)
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



            
