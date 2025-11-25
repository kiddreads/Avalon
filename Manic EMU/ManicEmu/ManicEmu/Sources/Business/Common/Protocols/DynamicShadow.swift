//
//  DynamicShadow.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/18.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

protocol DynamicShadow {
    func updateDynamicShadow(ofColor: UIColor, offset: CGSize, radius: CGFloat, opacity: Float)
}

extension DynamicShadow where Self: UIView {
    func updateDynamicShadow(ofColor: UIColor = .black, offset: CGSize = CGSize(width: 0, height: 5), radius: CGFloat = 10, opacity: Float = 0.05) {
        if traitCollection.userInterfaceStyle == .light {
            self.makeShadow(ofColor: ofColor, offset: offset, opacity: opacity)
        } else {
            self.removeShadow()
        }
    }
}
