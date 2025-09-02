//
//  AirPlayViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore

class AirPlayViewController: UIViewController {
    private var gameContainerView = UIView()
    
    var gameView: GameView?
    
    weak var libretroView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let icon = UIImageView(image: R.image.file_icon())
        view.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(200)
        }
        
        let label = UILabel(text: R.string.localizable.airPlayDesc(), style: .largeTitle)
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(icon.snp.bottom).offset(30)
        }
        
        view.addSubview(gameContainerView)
        gameContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func addGameView(_ gameView: GameView) {
        gameContainerView.transform = .identity
        gameContainerView.subviews.forEach { $0.removeFromSuperview() }
        gameContainerView.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalTo(view.height*gameView.size.width/gameView.size.height)
        }
        
        self.gameView = gameView
        gameContainerView.addSubview(gameView)
        gameView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func addLibretroView(_ gameView: UIView, dimensions: CGSize) {
        gameContainerView.transform = .identity
        gameContainerView.subviews.forEach { $0.removeFromSuperview() }
        let gameViewHeight = dimensions.height
        
        gameContainerView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(dimensions)
        }
        
        self.libretroView = gameView
        gameContainerView.addSubview(gameView)
        gameView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        DispatchQueue.main.asyncAfter(delay: 1) {
            let scale = self.view.frame.size.height/gameViewHeight
            self.gameContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
