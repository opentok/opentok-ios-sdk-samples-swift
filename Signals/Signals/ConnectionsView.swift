//
//  ConnectionsView.swift
//  junk
//
//  Created by Jaideep Shah on 2/9/23.
//

import SwiftUI

struct ConnectionsView {
    let all = [
        "Myself",
        "Stream 1132",
        "Stream 32084"
    ]
    @Binding var isAllConnections : Bool
    @State private var allSelect = Set<String>()
}
extension ConnectionsView: View {
   
    
    var body: some View {
        VStack {
            Toggle("Send signal to all connections:", isOn: $isAllConnections)
            if (isAllConnections == false) {
                Section("Select connection(s) to use:", content: {
                    List(all, id: \.self, selection: $allSelect) { name in
                        Text(name)
                    }
                    .multilineTextAlignment(.leading)
                    .environment(\.editMode, .constant(EditMode.active))
                })
            }
        }
    }
}

struct ConnectionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsView(isAllConnections: Binding.constant(true))
    }
}
