//
//  AddCheatCodeViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class AddCheatCodeViewController: BaseViewController {
    
    private lazy var addCheatCodeView: AddCheatCodeView = {
        let view = AddCheatCodeView(game: game, editGameCheat: editGameCheat)
        view.didTapClose = { [weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    private let game: Game
    private var editGameCheat: GameCheat? = nil

    init(game: Game, gameCheat: GameCheat? = nil) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
        editGameCheat = gameCheat
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(addCheatCodeView)
        addCheatCodeView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
