//
//  ProHUDExtentions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ProHUD

extension SheetTarget {
    func pop(completon: (()->Void)? = nil) {
        self.pop()
        self.onViewDidDisappear { _ in
            completon?()
        }
    }
}

extension AlertTarget {
    func pop(completon: (()->Void)? = nil) {
        self.pop()
        self.onViewDidDisappear { _ in
            completon?()
        }
    }
}


