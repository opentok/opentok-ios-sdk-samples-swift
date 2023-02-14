//
//  ContentView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .center) {

            
            SendSignalButtonView()
            
            
            //SignalParameterView()
           
            
            Divider()
            SignalMessagesView()
        }
        .padding(30)
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
