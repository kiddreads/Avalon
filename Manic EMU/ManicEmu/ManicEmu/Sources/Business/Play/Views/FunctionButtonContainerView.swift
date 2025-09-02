//
//  FunctionButtonContainerView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class FunctionButtonContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if subviews.contains(where: { $0 == view }) {
            return view
        }
        return nil
    }
}
