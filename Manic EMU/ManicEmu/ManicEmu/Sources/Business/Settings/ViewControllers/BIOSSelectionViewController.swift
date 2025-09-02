//
//  BIOSSelectionViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/10.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore

class BIOSSelectionViewController: BaseViewController {
    private lazy var biosSelectionView: BIOSSelectionView = {
        let view = BIOSSelectionView(gameType: self.gameType, showClose: self.showClose)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    var gameType: GameType? = nil
    let showClose: Bool
    
    init(gameType: GameType? = nil, showClose: Bool = true) {
        self.gameType = gameType
        self.showClose = showClose
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(biosSelectionView)
        biosSelectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
