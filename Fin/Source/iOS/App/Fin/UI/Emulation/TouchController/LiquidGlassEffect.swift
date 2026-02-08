// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

enum TouchControlStyle: String, CaseIterable, Identifiable {
    case standard
    case liquidGlass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .liquidGlass: return "Liquid Glass"
        }
    }
}

enum TouchControlStyleSetting {
    static let key = "DOLTouchControlStyle"
    static let defaultRawValue = TouchControlStyle.standard.rawValue

    static func current() -> TouchControlStyle {
        let raw = UserDefaults.standard.string(forKey: key) ?? defaultRawValue
        return TouchControlStyle(rawValue: raw) ?? .standard
    }

    static func setCurrent(_ style: TouchControlStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: key)
        NotificationCenter.default.post(name: .DOLTouchControlStyleChanged, object: nil)
    }
}

extension Notification.Name {
    static let DOLTouchControlStyleChanged = Notification.Name("DOLTouchControlStyleChanged")
}

extension UIView {
    /// Applies a "liquid glass" effect — a modern, dynamic blur/vibrancy/gloss background — to this view.
    /// Call after sizing the view, ideally during setup or layoutSubviews. Safe for UIImageView, UIButton, etc.
    /// - Parameter cornerRadius: Optionally customize the glass corner radius. Defaults to automatic rounding.
    func applyLiquidGlassEffect(cornerRadius: CGFloat? = nil) {
        let blurTag = 9983

        let r = cornerRadius ?? min(bounds.width, bounds.height) / 2

        // Live blur of background content (frosted glass)
        let blurView: UIVisualEffectView
        if let existing = subviews.first(where: { $0.tag == blurTag }) as? UIVisualEffectView {
            blurView = existing
        } else {
            let blur = UIBlurEffect(style: .systemThinMaterialDark)
            blurView = UIVisualEffectView(effect: blur)
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.isUserInteractionEnabled = false
            blurView.contentView.isUserInteractionEnabled = false
            blurView.tag = blurTag
            insertSubview(blurView, at: 0)
        }

        blurView.frame = bounds
        blurView.layer.cornerRadius = r
        blurView.layer.masksToBounds = true

        layer.cornerRadius = r
        layer.masksToBounds = true
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        layer.borderWidth = 0.5
        backgroundColor = .clear
    }

    func removeLiquidGlassEffect() {
        let blurTag = 9983
        subviews.first(where: { $0.tag == blurTag })?.removeFromSuperview()
        layer.borderWidth = 0
        layer.borderColor = nil
        layer.cornerRadius = 0
        layer.masksToBounds = false
    }

    func setLiquidGlassEffectEnabled(_ enabled: Bool, cornerRadius: CGFloat? = nil) {
        if enabled {
            applyLiquidGlassEffect(cornerRadius: cornerRadius)
        } else {
            removeLiquidGlassEffect()
        }
    }
}
