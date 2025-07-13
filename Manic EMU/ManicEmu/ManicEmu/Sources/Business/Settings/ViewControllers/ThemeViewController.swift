//
//  ThemeViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/5.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ThemeViewController: BaseViewController {
    
    private lazy var themeSettingView: ThemeSettingView = {
        let view = ThemeSettingView()
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(themeSettingView)
        themeSettingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
