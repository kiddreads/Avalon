//
//  BaseNavigationController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class BaseNavigationController: UINavigationController {
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        configStyle()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configStyle()
    }
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        configStyle()
    }
    
    func configStyle() {
        if let sheetPresentationController = self.sheetPresentationController {
            sheetPresentationController.preferredCornerRadius = Constants.Size.CornerRadiusMax
        }
    }
}
