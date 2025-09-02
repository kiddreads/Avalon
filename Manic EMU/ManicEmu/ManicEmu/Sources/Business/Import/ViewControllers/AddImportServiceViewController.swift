//
//  AddImportServiceViewController.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class AddImportServiceViewController: BaseViewController {
    private var addImportServiceView: AddImportServiceView
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init() is unavailable")
    }
    
    init(addImportServiceView: AddImportServiceView) {
        self.addImportServiceView = addImportServiceView
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(addImportServiceView)
        addImportServiceView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
