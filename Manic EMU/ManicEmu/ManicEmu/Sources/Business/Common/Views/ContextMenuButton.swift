//
//  ContextMenuButton.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class ContextMenuButton: UIButton {
    init(image: UIImage? = nil, menu: UIMenu? = nil) {
        super.init(frame: .zero)
        if let image = image {
            setImageForAllStates(image)
        }
        if let menu = menu {
            self.menu = menu
        }
        showsMenuAsPrimaryAction = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard enableInteractive else { return }
        touchMoved(touch: touches.first)
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard enableInteractive else { return }
        touchMoved(touch: touches.first)
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard enableInteractive else { return }
        if delayInteractiveTouchEnd {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: { [weak self] in
                self?.touchEnded(touch: touches.first)
            })
        } else {
            touchEnded(touch: touches.first)
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard enableInteractive else { return }
        if delayInteractiveTouchEnd {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: { [weak self] in
                self?.touchEnded(touch: touches.first)
            })
        } else {
            touchEnded(touch: touches.first)
        }
    }
    
    func triggerTapGesture() {
        if let gestureRecognizer = gestureRecognizers?.first(where: { $0.description.contains("UITouchDownGestureRecognizer") }) {
            gestureRecognizer.touchesBegan([], with: UIEvent())
        }
    }
}
