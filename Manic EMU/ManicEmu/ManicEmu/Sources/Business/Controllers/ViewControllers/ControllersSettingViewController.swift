//
//  ControllersSettingViewController.swift
//  ManicEmu
//
//  Created by Max on 2025/1/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class ControllersSettingViewController: BaseViewController {
    private var controllersSettingView: ControllersSettingView
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init() is unavailable")
    }
    
    init(controllersSettingView: ControllersSettingView) {
        self.controllersSettingView = controllersSettingView
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(controllersSettingView)
        controllersSettingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
