//
//  ContentView.swift
//  Signals
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
         
            SignalParameterView()
           
            SendSignalButtonView()
            Spacer()
            SignalMessagesView()
        }
        .padding(20)
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
