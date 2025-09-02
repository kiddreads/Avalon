//
//  SymbolView.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/31.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class SymbolView: UIImageView {
    /// 普通图标
    var normalSymbol: SFSymbol? {
        didSet {
            updateViews()
        }
    }
    
    /// 选中图标
    var selectedSymbol: SFSymbol? {
        didSet {
            updateViews()
        }
    }
    
    /// 普通颜色
    var normalColor: UIColor {
        didSet {
            updateViews()
        }
    }
    
    /// 选中玄色
    var selectedColor: UIColor? {
        didSet {
            updateViews()
        }
    }
    
    /// 图标大小
    var symbolPointSize: CGFloat {
        didSet {
            updateViews()
        }
    }
    
    /// 是否选中状态
    var isSelected: Bool = false {
        didSet {
            updateViews()
        }
    }
    
    /// 是否支持动画
    var animated: Bool = true {
        didSet {
            updateViews()
        }
    }
    
    init(normalSymbol: SFSymbol? = nil,
         selectedSymbol: SFSymbol? = nil,
         normalColor: UIColor = Constants.Color.LabelPrimary,
         selectedColor: UIColor? = nil,
         symbolPointSize: CGFloat = Constants.Size.SymbolSize,
         isSelected: Bool = false,
         animated: Bool = true) {
        self.normalColor = normalColor
        self.symbolPointSize = symbolPointSize
        super.init(frame: .zero)
        self.normalSymbol = normalSymbol
        self.selectedSymbol = selectedSymbol
        self.selectedColor = selectedColor
        self.isSelected = isSelected
        self.animated = animated
        self.contentMode = .center
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateViews() {
        guard let normalSymbol = self.normalSymbol else { return }
        let img = UIImage(symbol: isSelected ? (selectedSymbol ?? normalSymbol) : normalSymbol,
                          size: symbolPointSize,
                          color: isSelected ? (selectedColor ?? normalColor) : normalColor)
        image = img
    }
}
