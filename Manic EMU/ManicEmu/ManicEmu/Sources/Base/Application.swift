//
//  Application.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ManicEmuCore

private extension UIApplication {
    @objc(handleKeyUIEvent:)
    @NSManaged func handleKeyboardKey(for event: UIEvent)
}

class ManicApplication: UIApplication {
    // 上次键盘事件的时间戳，用于避免重复处理
    private static var lastKeyboardEventTimestamp: TimeInterval = 0
    
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
//        LibretroCore.sharedInstance().send(event)
    }
    
    // 处理键盘事件 - 对应Objective-C中的handleKeyUIEvent方法
    override func handleKeyboardKey(for event: UIEvent) {
        super.handleKeyboardKey(for: event)
        if #available(iOS 26.0, *) {
            guard let firstResponder = UIResponder.firstResponder as? ControllerView else { return }
            // 检查是否是重复的时间戳，避免重复处理
            if ManicApplication.lastKeyboardEventTimestamp == event.timestamp {
                return
            }
            
            ManicApplication.lastKeyboardEventTimestamp = event.timestamp
            
            firstResponder.handleKeyboardKey(for: event)
        }
    }
    
    
}
