//
//  EmulatorCoreExtentions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import ManicEmuCore
import MelonDSDeltaCore

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
                    LibretroCore.sharedInstance().fastForward(3.0)
                case .four:
                    LibretroCore.sharedInstance().fastForward(4.0)
                case .five:
                    LibretroCore.sharedInstance().fastForward(5.0)
                }
            } else {
                let count = Double(GameSetting.FastForwardSpeed.allCases.count)
                let rate = 1 + (maximumFastForwardSpeed - 1)/(count-1)*Double(speed.rawValue-1)
                self.rate = rate
            }
        }
    }
    
    var maximumFastForwardSpeed: Double {
        switch self.manicCore
        {
        case MelonDS.core where UIDevice.current.hasA15ProcessorOrBetter: return 10
        case MelonDS.core where UIDevice.current.hasA11ProcessorOrBetter: return 5
        default: return 1
        }
    }
    
}
