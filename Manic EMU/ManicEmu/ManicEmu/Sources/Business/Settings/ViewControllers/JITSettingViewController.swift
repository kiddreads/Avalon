//
//  JITSettingViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class JITSettingViewController: BaseViewController {
    private lazy var jitSettingView: JITSettingView = {
        let view = JITSettingView(showClose: self.showClose)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    let showClose: Bool
    
    init(showClose: Bool = true) {
        self.showClose = showClose
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(jitSettingView)
        jitSettingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
