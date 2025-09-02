//
//  TitleHaderCollectionReusableView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class BlackHaderReusableView: UICollectionReusableView {
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

class BackgroundHaderReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelSecondary
        view.font = Constants.Font.body(size: .s, weight: .semibold)
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

class PrimaryHaderReusableView: UICollectionReusableView {
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

class PrimaryButtonHaderReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelPrimary
        view.font = Constants.Font.title(size: .s)
        return view
    }()
    
    var button: SymbolButton = {
        let view = SymbolButton(image: R.image.customArrowTrianglehead2Clockwise()?.applySymbolConfig(font: Constants.Font.body(weight: .bold)))
        view.enableRoundCorner = true
        view.backgroundColor = Constants.Color.BackgroundPrimary
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel, button])
        makeBlur(blurColor: Constants.Color.BackgroundPrimary)
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
        }
        
        button.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.equalTo(titleLabel.snp.trailing)
            make.size.equalTo(Constants.Size.ItemHeightTiny)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
