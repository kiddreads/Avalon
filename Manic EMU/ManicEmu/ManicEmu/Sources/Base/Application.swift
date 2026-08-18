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
    // 键盘事件已统一由 DeltaCore 的 KeyboardGameController（GCKeyboard）采集，
    // 不再使用 handleKeyUIEvent 私有 API 通路。
    
    override func sendEvent(_ event: UIEvent) {
        // 用户触摸屏幕代表切换为触摸操作意图，移除 FocusKit 当前焦点（位置已记忆，方向键可恢复）
        if event.type == .touches,
           let touches = event.allTouches,
           touches.contains(where: { $0.phase == .began }) {
            FocusSystem.shared.userDidTouchScreen()
        }
        super.sendEvent(event)
//        if PlayViewController.isGaming, PlayViewController.currentGameType == .dos {
//            LibretroCore.sharedInstance().send(event)
//        }
    }
    
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let event, PlayViewController.isGaming, PlayViewController.currentGameType == .dos {
            for press in presses {
                LibretroCore.sharedInstance().handle(press, with: event, down: true)
            }
        }
        super.pressesBegan(presses, with: event)
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let event, PlayViewController.isGaming, PlayViewController.currentGameType == .dos {
            for press in presses {
                LibretroCore.sharedInstance().handle(press, with: event, down: false)
            }
        }
        super.pressesEnded(presses, with: event)
    }
    
}
