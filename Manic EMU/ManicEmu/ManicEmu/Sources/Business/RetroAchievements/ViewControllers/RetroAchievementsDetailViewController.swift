//
//  RetroAchievementsDetailViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroAchievementsDetailViewController: BaseViewController {
    init(achievement: CheevosAchievement) {
        super.init(fullScreen: true)
        view.backgroundColor = .clear
        view.makeBlur()
        
        let detailView = RetroAchievementsDetailView(achievement: achievement) { [weak self] in
            self?.dismiss(animated: true)
        }
        view.addSubview(detailView)
        detailView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
