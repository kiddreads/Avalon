//
//  CheatCodeViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class CheatCodeViewController: BaseViewController {
    
    private lazy var cheatCodeListView: CheatCodeListView = {
        let view = CheatCodeListView(game: game)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        
        view.didTapAdd = {[weak self] in
            guard let self = self else { return }
            self.present(AddCheatCodeViewController(game: self.game), animated: true)
        }
        
        view.didTapEdt = {[weak self] gameCheat in
            guard let self = self else { return }
            self.present(AddCheatCodeViewController(game: self.game, gameCheat: gameCheat), animated: true)
        }
        return view
    }()
    
    private let game: Game

    init(game: Game) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(cheatCodeListView)
        cheatCodeListView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
