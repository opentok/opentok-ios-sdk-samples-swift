//
//  ContentView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct ContentView {
    @State var showEnterData = false
    @StateObject  var vonageVideo = VonageVideo()
    @State private var signalType = "Greetings"
    @State private var signalData = "Hello World"
    @State private var isRetryOnReconnect = false
    
}
extension ContentView: View {
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                if (vonageVideo.isSessionConnected == false) {
                    Text("Connecting...")
                } else {
                    if showEnterData == false {
                        SendSignalButtonView(enterData: $showEnterData)
                    
                        SignalMessagesView()
                    }
                    else  {
                        VStack {
                            SignalParameterView(signalType: $signalType, signalData: $signalData, retryAfterConnect: $isRetryOnReconnect)
                            Button(action: {
                                self.showEnterData.toggle()
                            }) {
                                Text("Close")
                            }
                        }
                    }
                }

                
            }
            .padding(30)
            .environmentObject(vonageVideo)
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



            
