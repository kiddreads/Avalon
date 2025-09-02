//
//  RadomGameCollectionReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class RandomGameCollectionReusableView: UICollectionReusableView {
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelPrimary
        view.font = Constants.Font.body()
        view.text = R.string.localizable.gamesRandom()
        return view
    }()
    
    var iconImage: UIImageView = {
        let view = UIImageView(image: .symbolImage(.diceFill))
        view.contentMode = .center
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        enableInteractive = true
        delayInteractiveTouchEnd = true
        
        addSubviews([iconImage, titleLabel])
    
        iconImage.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.centerX.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeMin)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImage.snp.bottom).offset(Constants.Size.ContentSpaceUltraTiny)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
