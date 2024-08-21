//
//  OTCombine.swift
//  Basic-Video-Chat
//
//  Created by Jaideep Shah on 8/21/24.
//  Copyright © 2024 tokbox. All rights reserved.
//

import Foundation
import OpenTok
import Combine

class OTSwPublisher: OTPublisher, OTPublisherKitNetworkStatsDelegate {
    public var namePublisher: Just<String>
    
    override init?(delegate: (any OTPublisherKitDelegate)?) {
        self.namePublisher = Just("")
        super.init(delegate: delegate)
        self.namePublisher =  Just(self.name ?? "" )
    }
    
    override init?(delegate: (any OTPublisherKitDelegate)?, settings: OTPublisherSettings) {
        self.namePublisher = Just("")
        super.init(delegate: delegate, settings: settings)
        self.namePublisher =  Just(self.name ?? "")
    }

}
