//
//  PretendoNetworkingViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PretendoNetworkingViewController: BaseViewController {
    private lazy var pretendoNetworkingView: PretendoNetworkingView = {
        let view = PretendoNetworkingView()
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(pretendoNetworkingView)
        pretendoNetworkingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
