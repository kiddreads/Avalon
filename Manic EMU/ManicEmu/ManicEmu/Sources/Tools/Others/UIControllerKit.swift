//
//  UIControllerKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore
import KeyboardKit

class UIControllerKit {
    static let shared = UIControllerKit()
    private var externalGameControllerDidPress: Any? = nil
    private var externalGameControllerDidRelease: Any? = nil
    private var thumbStickHoldings: [String: Bool] = ["leftThumbstickLeft": false,
                                                      "leftThumbstickRight": false,
                                                      "leftThumbstickUp": false,
                                                      "leftThumbstickDown": false,
                                                      "rightThumbstickLeft": false,
                                                      "rightThumbstickRight": false,
                                                      "rightThumbstickUp": false,
                                                      "rightThumbstickDown": false]
    
    deinit {
        if let externalGameControllerDidPress {
            NotificationCenter.default.removeObserver(externalGameControllerDidPress)
        }
        
        if let externalGameControllerDidRelease {
            NotificationCenter.default.removeObserver(externalGameControllerDidRelease)
        }
    }
    
    func start() {
        externalGameControllerDidPress = NotificationCenter.default.addObserver(forName: .externalGameControllerDidPress, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            if let userInfo = notification.userInfo,
               let input = userInfo["input"] as? any Input,
               let _ = userInfo["value"] as? Double {
               
                guard let firstResponder = UIResponder.firstResponder else { return }

                //游戏中则直接返回
                if firstResponder is ControllerView {
                    return
                }
                
                var current = firstResponder
                var pressableResponders: [any UIControllerPressable] = []
                if let current = current as? any UIControllerPressable {
                    pressableResponders.append(current)
                }
                
                while let next = current.next {
                    if next is ControllerView {
                        break
                    }
                    if let nextResponder = next as? UIControllerPressable {
                        pressableResponders.append(nextResponder)
                    }
                    current = next
                }
                
                guard pressableResponders.count > 0 else { return }
                
                var key: UIControllerKey? = nil
                let inputString = input.stringValue
                
                if let holding = self.thumbStickHoldings[inputString] {
                    if holding {
                        return
                    } else {
                        self.thumbStickHoldings[inputString] = true
                    }
                }
                
                if inputString == "left" || inputString == "leftThumbstickLeft" || inputString == "rightThumbstickLeft" {
                    key = .left
                } else if inputString == "right" || inputString == "leftThumbstickRight" || inputString == "rightThumbstickRight" {
                    key = .right
                } else if inputString == "up" || inputString == "leftThumbstickUp" || inputString == "rightThumbstickUp" {
                    key = .up
                } else if inputString == "down" || inputString == "leftThumbstickDown" || inputString == "rightThumbstickDown" {
                    key = .down
                } else if inputString == "a" {
                    key = .a
                } else if inputString == "b" {
                    key = .b
                }  else if inputString == "leftShoulder" {
                    key = .l1
                } else if inputString == "rightShoulder" {
                    key = .r1
                } else if inputString == "leftTrigger" {
                    key = .l2
                } else if inputString == "rightTrigger" {
                    key = .r2
                } else if inputString == "leftThumbstickButton" {
                    key = .l3
                } else if inputString == "rightThumbstickButton" {
                    key = .r3
                } else if inputString == "x" {
                    key = .x
                } else if inputString == "y" {
                    key = .y
                }
                Log.debug("控制器点击:\(inputString)")
                if let key {
                    Log.debug("响应控制器点击的Responders:\(pressableResponders.map({ String(describing: type(of: $0)) }))")
                    pressableResponders.forEach { $0.didControllerPress(key: key) }
                }
            }
        }
        
        externalGameControllerDidRelease = NotificationCenter.default.addObserver(forName: .externalGameControllerDidRelease, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            if let userInfo = notification.userInfo,
               let input = userInfo["input"] as? any Input {
                let inputString = input.stringValue
                if let _ = self.thumbStickHoldings[inputString] {
                    self.thumbStickHoldings[inputString] = false
                }
            }
        }
    }
}
