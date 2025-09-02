//
//  DownloadViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/29.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class DownloadViewController: BaseViewController {
    private let downloadManageView = DownloadManageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(downloadManageView)
        downloadManageView.didTapClose = { [weak self] in
            self?.dismiss(animated: true)
        }
        downloadManageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
