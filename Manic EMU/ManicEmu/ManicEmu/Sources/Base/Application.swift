//
//  Application.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit

class ManicApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
//        LibretroCore.sharedInstance().send(event)
    }
}
