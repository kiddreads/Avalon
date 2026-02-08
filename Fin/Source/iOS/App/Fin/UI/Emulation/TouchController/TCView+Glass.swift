// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

extension UIView {
    func applyLiquidGlassEffect(cornerRadius: CGFloat? = nil) {
        let actualCornerRadius = cornerRadius ?? (bounds.height / 2)
        
        // Remove any existing blur views and gradient layers to avoid stacking
        subviews.filter { $0.accessibilityIdentifier == "GlassBlurView" }.forEach { $0.removeFromSuperview() }
        layer.sublayers?.filter { $0.name == "GlassGradientLayer" }.forEach { $0.removeFromSuperlayer() }
        
        // 1. Setup the Blur Effect
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = self.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = actualCornerRadius
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        blurView.accessibilityIdentifier = "GlassBlurView"
        
        // 2. Setup Vibrancy for the content
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .fill)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.frame = blurView.bounds
        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.addSubview(vibrancyView)
        
        // 3. Styling the border (The "Glass" edge)
        self.layer.cornerRadius = actualCornerRadius
        self.layer.borderColor = UIColor(white: 1.0, alpha: 0.4).cgColor
        self.layer.borderWidth = 0.5
        
        // 4. Inner Glow / Shine
        let gradient = CAGradientLayer()
        gradient.name = "GlassGradientLayer"
        gradient.frame = self.bounds
        gradient.colors = [
            UIColor.white.withAlphaComponent(0.2).cgColor,
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.05).cgColor
        ]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.cornerRadius = actualCornerRadius
        self.layer.insertSublayer(gradient, at: 0)
        
        // 5. Shadow for depth
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 8
        self.layer.shadowOpacity = 0.3
        
        self.insertSubview(blurView, at: 0)
        
        // Set background clear so blur is visible
        self.backgroundColor = .clear
    }
}
