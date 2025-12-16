//
//  CallViewController.swift
//  Teleclinic
//
//  Created on 16/08/24.
//  Copyright © 2024 Teleclinic GmbH. All rights reserved.
//

import UIKit
import SwiftUI

final class CallViewController: UIHostingController<CallView> {

    init(viewModel: CallViewModel, onFinish: @escaping () -> Void) {
        super.init(rootView: CallView(viewModel: viewModel, onFinish: onFinish))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
