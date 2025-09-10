//
//  RetroAchievementsDetailViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroAchievementsDetailViewController: BaseViewController {
    
    private let containerView = UIView()
    
    init(achievement: CheevosAchievement) {
        super.init(fullScreen: true)
        view.backgroundColor = .clear
        
        view.addSubview(containerView)
        containerView.makeBlur()
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let detailView = RetroAchievementsDetailView(achievement: achievement) { [weak self] in
            self?.dismiss(animated: true)
        }
        containerView.addSubview(detailView)
        detailView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
        
        let shareButton = SymbolButton(image: UIImage(symbol: .squareAndArrowUp, font: Constants.Font.body(weight: .bold)))
        shareButton.enableRoundCorner = true
        shareButton.addTapGesture { [weak self] gesture in
            guard let self else { return }
            ShareManager.shareImage(image: self.containerView.asImage())
        }
        view.addSubview(shareButton)
        shareButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
