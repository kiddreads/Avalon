//
//  ControllableSideMenu.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SideMenu
import KeyboardKit

class ControllableSideMenu: SideMenuNavigationController {}

extension ControllableSideMenu: UIControllerPressable {
    override var canBecomeFirstResponder: Bool { true }
    
    override var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []
        commands.append(UIKeyCommand(input: "[", modifierFlags: [], action: #selector(didSideMenuKeyboardPress)))
        commands.append(UIKeyCommand(input: "]", modifierFlags: [], action: #selector(didSideMenuKeyboardPress)))
        return commands
    }
    
    
    func didControllerPress(key: UIControllerKey) {
        if key == .l2 || key == .r2 {
            self.dismiss(animated: true)
        }
    }
    
    @objc func didSideMenuKeyboardPress(_ sender: UIKeyCommand) {
        if let inputString = sender.input {
            if inputString == "[" || inputString == "]" {
                self.dismiss(animated: true)
            }
        }
    }
}
