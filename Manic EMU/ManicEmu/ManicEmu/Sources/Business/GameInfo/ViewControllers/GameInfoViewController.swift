//
//  GameInfoViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class GameInfoViewController: BaseViewController {
    
    private lazy var gameInfoView: GameInfoView = {
        let view = GameInfoView(game: game, readyAction: readyAction, showGameSaveOnly: showGameSaveOnly)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    private let game: Game
    private let readyAction: GameInfoView.ReadyAction
    private let showGameSaveOnly: Bool
   
    init(game: Game, readyAction: GameInfoView.ReadyAction = .default, showGameSaveOnly: Bool = false) {
        self.game = game
        self.readyAction = readyAction
        self.showGameSaveOnly = showGameSaveOnly
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(gameInfoView)
        gameInfoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        gameInfoView.controllerViewDidAppear()
    }
}

