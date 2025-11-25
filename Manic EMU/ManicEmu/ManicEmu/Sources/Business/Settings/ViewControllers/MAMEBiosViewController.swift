//
//  MAMEBiosViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class MAMEBiosViewController: BaseViewController {
    private lazy var mameBiosView: MAMEBiosView = {
        let view = MAMEBiosView()
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(mameBiosView)
        mameBiosView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
