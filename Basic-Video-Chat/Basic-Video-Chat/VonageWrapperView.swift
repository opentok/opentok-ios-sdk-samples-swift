//
//  VonageWrapperView.swift
//  Teleclinic
//
//  Created on 05/06/24.
//  Copyright © 2024 Teleclinic GmbH. All rights reserved.
//

import SwiftUI
import UIKit

// This implementation differs from what Vonage recommends:
// https://developer.vonage.com/en/blog/how-to-make-video-calls-with-swiftui#building-the-video-chat-ui
//
// struct OTView: UIViewRepresentable {
//     @State var view: UIView
//
//     func makeUIView(context: Context) -> UIView {
//         return view
//     }
//
//     func updateUIView(_ uiView: UIView, context: Context) {
//         DispatchQueue.main.async {
//             self.view = uiView
//         }
//     }
// }
//
// This does not work!!!
//
// updateUIView() is called when the SwiftUI view properties change and is supposed to CHANGE the UIKit view, not to provide a new one.
// Changing a state variable that holds the current view has no effect, since makeUIView() is NOT called again.
// makeUIView() is only called once in a view lifecycle.
// Besides that, it is already problematic to have a @State variable that is ALSO passed as a view property.
// That is why @State variables should always be private, to avoid this mistake!
// updateUIView() gets called BECAUSE the view property changes, and it then sets the same (state) variable to that value.
// Instead, it should not be a @State variable to begin with, it should simply be a regular view property.
//
// What really should be done is to make sure that makeUIView() is called for each new UIKit view.
// And that can only be achieved by giving the outer SwiftUI view an .id() that changes when the UIKit view changes,
// which changes when the stream (id) changes.

struct VonageWrapperView: UIViewRepresentable {
    var uiView: UIView

    func makeUIView(context: Context) -> UIView {
        uiView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
