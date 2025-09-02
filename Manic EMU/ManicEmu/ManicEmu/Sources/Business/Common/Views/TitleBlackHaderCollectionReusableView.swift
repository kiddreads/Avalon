//
//  TitleHaderCollectionReusableView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class TitleBlackHaderCollectionReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelPrimary
        view.font = Constants.Font.title(size: .s)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel])
        makeBlur(blurColor: .black)
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}

class TitleBackgroundColorHaderCollectionReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelPrimary
        view.font = Constants.Font.title(size: .s)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel])
        makeBlur(blurColor: Constants.Color.Background)
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}

class TitleBackgroundPrimaryColorHaderCollectionReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelPrimary
        view.font = Constants.Font.title(size: .s)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel])
        makeBlur(blurColor: Constants.Color.BackgroundPrimary)
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
