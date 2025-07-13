//
//  SkinSettingsViewController.swift
//  ManicEmu
//
//  Created by Max on 2025/1/25.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit
import ManicEmuCore

class SkinSettingsViewController: BaseViewController {
    
    private lazy var skinSettingsView: SkinSettingsView = {
        let view = SkinSettingsView(game: game, gameType: gameType)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    private let game: Game?
    private let gameType: GameType?
    
    /// 初始化控制器 如果game和gameType都不传入 则使用默认规则展示 默认优先展示GBA的skin 两个都传入只读取game
    /// - Parameters:
    ///   - game: 游戏 如果传入一个确定的游戏 则只为这个游戏设置皮肤 不能切换或设置别的平台的skin
    ///   - gameType: 传入游戏类型 则有限展示次类型的skin 可以切换其他平台
    init(game: Game? = nil, gameType: GameType? = nil) {
        self.game = game
        self.gameType = gameType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(skinSettingsView)
        skinSettingsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
