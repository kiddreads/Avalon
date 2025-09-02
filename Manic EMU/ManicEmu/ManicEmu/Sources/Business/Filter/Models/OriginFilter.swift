//
//  OriginFilter.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class OriginFilter: CIFilter {
    static let name = R.string.localizable.filterOriginTitle()
    override init() {
        super.init()
        name = OriginFilter.name
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
