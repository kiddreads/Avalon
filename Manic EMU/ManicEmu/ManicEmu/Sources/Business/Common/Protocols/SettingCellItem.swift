//
//  SettingCellItem.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/5.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

protocol SettingCellItem {
    var image: UIImage { get }
    var title: String { get }
    var enableLongPress: Bool { get }
}
