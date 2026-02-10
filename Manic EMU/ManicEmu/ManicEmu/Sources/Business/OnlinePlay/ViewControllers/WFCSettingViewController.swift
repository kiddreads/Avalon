//
//  WFCSettingViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class WFCSettingViewController: BaseViewController {
    private lazy var wfcSettingView: WFCSettingView = {
        let view = WFCSettingView()
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(wfcSettingView)
        wfcSettingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
