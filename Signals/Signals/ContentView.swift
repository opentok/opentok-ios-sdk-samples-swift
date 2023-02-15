//
//  ContentView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI
struct ContentView {
    @State var showEnterData = false
}
extension ContentView: View {
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                
                if showEnterData == false {
                    SendSignalButtonView(enterData: $showEnterData)
                    SignalMessagesView()
                }
                else  {
                    VStack {
                        SignalParameterView()
                        Button(action: {
                            self.showEnterData.toggle()
                        }) {
                            Text("Set")
                        }
                    }
                }
                
            }
            .padding(30)
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



            
