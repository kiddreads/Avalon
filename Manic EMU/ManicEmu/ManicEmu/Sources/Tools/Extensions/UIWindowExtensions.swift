//
//  UIWindowExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/26.
//  Copyright © 2024 Manic EMU. All rights reserved.
//

import Foundation


extension UIWindow {
    static var applicationWindow: UIWindow? {
        return ApplicationSceneDelegate.applicationWindow
    }
    
    func showDropView() {
        guard subviews.first(where: { $0 is DropGlowEffectView }) == nil else { return }
        let dropView = DropGlowEffectView()
        addSubview(dropView)
        dropView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        dropView.alpha = 0
        UIView.normalAnimate {
            dropView.alpha = 1
        }
    }
    
    func hideDropView() {
        subviews.forEach { subView in
            if subView is DropGlowEffectView {
                UIView.normalAnimate {
                    subView.alpha = 0
                } completion: { _ in
                    subView.removeFromSuperview()
                }
            }
        }
    }
}
