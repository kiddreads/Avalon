//
//  FocusKeyObserver.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation

/// 将游戏控制器与键盘事件统一转换为 FocusKey 输入的监听器。
///
/// 控制器与键盘事件均来自 DeltaCore 的 externalGameControllerDidPress/DidRelease 通知：
/// 键盘由 DeltaCore 的 KeyboardGameController 通过 GCKeyboard（HID 原始按键状态）采集，
/// 完全绕开 UIKit 的 UIKeyCommand/系统快捷键消费机制（系统保留组合如 ⌃⌘F 除外）。
///
/// 仅在 ExternalInputDispatch.sink == .focusKit 时处理（未游戏或游戏已暂停）。
/// 游戏运行中的按键由 PlayViewController 与模拟核心接收，不经过本类。
///
/// 本类只负责两件事：
/// 1. 摇杆方向输入的按住去重；
/// 2. 键盘修饰键组合成 chord，固定顺序 control → option → shift → command，
///    与按下先后无关；释放修饰键时输出释放前按住的完整组合，保证 press/release 配套。
class FocusKeyObserver {
    static let shared = FocusKeyObserver()
    
    private var externalGameControllerDidPress: Any? = nil
    private var externalGameControllerDidRelease: Any? = nil
    private var externalGameControllerDidDisconnect: Any? = nil
    private var externalKeyboardDidDisconnect: Any? = nil
    
    // MARK: - 键盘状态
    
    /// 修饰键的固定输出顺序（与按下的先后顺序无关）：control → option → shift → command
    private static let modifierOrder = ["control", "option", "shift", "command"]
    /// 当前按住的修饰键名（DeltaCore 已将左右同名修饰键合并为同一输入）
    private static var heldModifiers = Set<String>()
    /// 非修饰键按下时记录的组合键名，释放时原样回放保证对称
    private static var activeComposedKeys = [String: String]()
    
    func start() {
        _ = FocusSystem.shared
        externalGameControllerDidPress = NotificationCenter.default.addObserver(forName: .externalGameControllerDidPress, object: nil, queue: .main) { notification in
            guard ExternalInputDispatch.sink == .focusKit else { return }
            
            if let userInfo = notification.userInfo,
               let input = userInfo["input"] as? any Input {
                
                if input.type == .controller(.keyboard) {
                    if FocusSystem.shared.isEditingText {
                        // Letters stay with the field; Escape still ends editing.
                        if input.stringValue == "escape" {
                            Self.handleKeyboard(input.stringValue, isPressed: true)
                        }
                        return
                    }
                    Self.handleKeyboard(input.stringValue, isPressed: true)
                    return
                }
                
                Self.activateKey(input.stringValue)
            }
        }
        
        externalGameControllerDidRelease = NotificationCenter.default.addObserver(forName: .externalGameControllerDidRelease, object: nil, queue: .main) { notification in
            guard ExternalInputDispatch.sink == .focusKit else { return }
            
            if let userInfo = notification.userInfo,
               let input = userInfo["input"] as? any Input {
                
                if input.type == .controller(.keyboard) {
                    Self.handleKeyboard(input.stringValue, isPressed: false)
                    return
                }
                
                Self.deactivateKey(input.stringValue)
            }
        }
        
        // 手柄或外接键盘断开：无剩余外设时清掉焦点高亮
        let onDisconnect: (Notification) -> Void = { notification in
            if notification.object is KeyboardGameController {
                Self.resetKeyboardState()
            }
            FocusSystem.shared.handleExternalInputDidChange()
        }
        externalGameControllerDidDisconnect = NotificationCenter.default.addObserver(
            forName: .externalGameControllerDidDisconnect,
            object: nil,
            queue: .main,
            using: onDisconnect
        )
        externalKeyboardDidDisconnect = NotificationCenter.default.addObserver(
            forName: .externalKeyboardDidDisconnect,
            object: nil,
            queue: .main,
            using: onDisconnect
        )
    }
    
    // MARK: - 键盘处理
    
    func handleTextEditingDidBegin() {
        Self.resetKeyboardState()
    }
    
    private static func resetKeyboardState() {
        heldModifiers.removeAll()
        activeComposedKeys.removeAll()
    }
    
    private static func handleKeyboard(_ keyName: String, isPressed: Bool) {
        let isModifier = modifierOrder.contains(keyName)
        
        if isPressed {
            if isModifier {
                guard !heldModifiers.contains(keyName) else { return }
                heldModifiers.insert(keyName)
                // 修饰键按下：输出当前按住的全部修饰键组合（固定顺序）
                activateKey(composedChord())
            } else {
                guard activeComposedKeys[keyName] == nil else { return }
                let composed = composedKey(with: keyName)
                activeComposedKeys[keyName] = composed
                activateKey(composed)
            }
        } else {
            if isModifier {
                guard heldModifiers.contains(keyName) else { return }
                // 修饰键释放：输出释放前按住的全部修饰键组合（含被释放的键，固定顺序），
                // 与 activate 时的组合配套。例如按住 control+shift+command 依次释放：
                // release: control+shift+command → control+command → command
                let composed = composedChord()
                heldModifiers.remove(keyName)
                deactivateKey(composed)
            } else {
                guard let composed = activeComposedKeys.removeValue(forKey: keyName) else { return }
                deactivateKey(composed)
            }
        }
    }
    
    /// 当前按住的全部修饰键，按固定顺序组合（如 "control+shift+command"）
    private static func composedChord() -> String {
        return modifierOrder.filter { heldModifiers.contains($0) }.joined(separator: "+")
    }
    
    /// 普通键与当前按住的修饰键组合（如 "control+command+f"）
    private static func composedKey(with keyName: String) -> String {
        var parts = modifierOrder.filter { heldModifiers.contains($0) }
        parts.append(keyName)
        return parts.joined(separator: "+")
    }
    
    // MARK: - 输出
    
    private static func activateKey(_ key: String) {
        FocusSystem.shared.keyDown(mappingKey(key))
    }
    
    private static func deactivateKey(_ key: String) {
        // 释放时走同样的映射，保证 keyDown/keyUp 配对
        FocusSystem.shared.keyUp(mappingKey(key))
    }
    
    private static func mappingKey(_ key: String) -> FocusKey {
        if key == "leftThumbstickLeft" {
            return .left
        } else if key == "leftThumbstickRight" {
            return .right
        } else if key == "leftThumbstickUp" {
            return .up
        } else if key == "leftThumbstickDown" {
            return .down
        } else if key == "rightThumbstickLeft" {
            return .left
        } else if key == "rightThumbstickRight" {
            return .right
        } else if key == "rightThumbstickUp" {
            return .up
        } else if key == "rightThumbstickDown" {
            return .down
        } else if key == "return" {
            return .a
        } else if key == "escape" {
            return .b
        }
        return FocusKey(key)
    }
    
}
