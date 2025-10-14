//
//  GameplayManualsViewController.swift
//  ManicEmu
//
//  Created by Aoshuang on 2025/10/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class GameplayManualsViewController: BaseViewController {
    
    private lazy var gameplayManualsView: GameplayManualsView = {
        let view = GameplayManualsView(game: game)
        view.didTapClose = { [weak self] in
            self?.dismiss(animated: true)
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
        
        view.addSubview(gameplayManualsView)
        gameplayManualsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
