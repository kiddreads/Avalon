//
//  GameSettingSortCollectionReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/11.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class GameSettingSortCollectionReusableView: UICollectionReusableView {
    var descLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.font = Constants.Font.caption(size: .l)
        view.textColor = Constants.Color.LabelSecondary
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let seperator = SparkleSeperatorView(color: Constants.Color.BackgroundSecondary)
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(16)
            make.top.equalToSuperview().offset(Constants.Size.ContentSpaceTiny)
        }
        
        addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(seperator.snp.bottom).offset(Constants.Size.ContentSpaceMin)
            make.centerX.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
