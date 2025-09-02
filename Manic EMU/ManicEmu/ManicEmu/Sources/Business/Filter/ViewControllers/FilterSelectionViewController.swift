//
//  FilterSelectionViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/7.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import UIKit
import ManicEmuCore

class FilterSelectionViewController: BaseViewController {
    
    private lazy var filterSelectionView: FilterSelectionView = {
        let view = FilterSelectionView(game: game, snapshot: snapshot)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    private let game: Game
    private let snapshot: UIImage?
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    init(game: Game, snapshot: UIImage? = nil) {
        self.game = game
        self.snapshot = snapshot
        super.init(nibName: nil, bundle: nil)
        Log.debug("\(String(describing: Self.self)) init")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(filterSelectionView)
        filterSelectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
