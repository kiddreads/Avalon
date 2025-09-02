//
//  TouchController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore
import GameController

enum PlayerIndex: Int, CaseIterable {
    case indexUnset = -1
    case index1 = 0
    case index2 = 1
    case index3 = 2
    case index4 = 3
    
    static var playerCases: [PlayerIndex] {
        [.index1, .index2, .index3, .index4]
    }
}

extension GameController {
    var image: UIImage {
        switch inputType {
        case .controllerSkin:
                .symbolImage(.rectangleFillOnRectangleFill)
        case .mfi:
                .symbolImage(.gamecontrollerFill)
        case .keyboard:
                .symbolImage(.keyboardFill)
        default:
                .symbolImage(.dpadLeftFilled)
        }
    }
}


class TouchController: NSObject, GameController {
    var name: String {
        R.string.localizable.controllersTouchName()
    }
    
    var inputType: GameControllerInputType {
        .controllerSkin
    }
    var playerIndex: Int?
    
    var defaultInputMapping: (any ManicEmuCore.GameControllerInputMappingBase)?
}
