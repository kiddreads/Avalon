//
//  EmulatorCoreExtentions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import ManicEmuCore

extension EmulatorCore {
    func setRate(speed: GameSetting.FastForwardSpeed) {
        switch speed {
        case .one:
            if manicCore.gameType.isLibretroType {
                LibretroCore.sharedInstance().fastForward(0.0)
            } else {
                self.rate = 1
            }
        default:
            if manicCore.gameType.isLibretroType {
                switch speed {
                case .one:
                    LibretroCore.sharedInstance().fastForward(1.0)
                case .two:
                    LibretroCore.sharedInstance().fastForward(1.4)
                case .three:
                    LibretroCore.sharedInstance().fastForward(3)
                case .four:
                    LibretroCore.sharedInstance().fastForward(5)
                case .five:
                    LibretroCore.sharedInstance().fastForward(7)
                }
            }
        }
    }
    
}
