//
//  CGRectExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

extension CGRect {
    func rounded(_ numberOfDecimalPlaces: Int = 2) -> CGRect {
        return CGRect(x: self.origin.x.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero),
                      y: self.origin.y.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero),
                      width: self.size.width.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero),
                      height: self.size.height.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero))
    }
}
