//
//  PlayHistoryViewController.swift
//  ManicEmu
//
//  Created by Max on 2025/1/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class PlayHistoryViewController: BaseViewController {
    private var playHistoryView: PlayHistoryView
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init() is unavailable")
    }
    
    init(playHistoryView: PlayHistoryView) {
        self.playHistoryView = playHistoryView
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(playHistoryView)
        playHistoryView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
