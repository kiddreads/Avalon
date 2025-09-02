//
//  Application.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class ManicApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
//        LibretroCore.sharedInstance().send(event)
    }
}
