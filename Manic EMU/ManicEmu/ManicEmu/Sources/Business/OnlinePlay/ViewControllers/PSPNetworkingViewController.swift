//
//  PSPNetworkingViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PSPNetworkingViewController: BaseViewController {
    private lazy var pspNetworkingView: PSPNetworkingView = {
        let view = PSPNetworkingView()
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(pspNetworkingView)
        pspNetworkingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
