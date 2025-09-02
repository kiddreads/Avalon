//
//  GameCoverSearchViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class GameCoverSearchViewController: BaseViewController {
    
    private lazy var gameCoverSearchView: GameCoverSearchView = {
        let view = GameCoverSearchView(game: self.game)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        view.didSelectIamge = { [weak self] image in
            self?.didSelectIamge?(image)
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    private var game: Game
    
    private var didSelectIamge: ((UIImage?)->Void)? = nil
    
    init(game: Game, completion: ((UIImage?)->Void)? = nil) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
        self.didSelectIamge = completion
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.isPad {
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                self.gameCoverSearchView.collectionView.reloadData()
            }
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(gameCoverSearchView)
        gameCoverSearchView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
