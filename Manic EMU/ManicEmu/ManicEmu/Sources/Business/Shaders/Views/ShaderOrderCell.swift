//
//  ShaderOrderCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import SwipeCellKit

class ShaderOrderCell: SwipeCollectionViewCell {
    private var titleLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelPrimary
        return label
    }()
    
    private let icon = SymbolButton(image: .init(symbol: .line3Horizontal, font: Constants.Font.title(size: .s), color: Constants.Color.BackgroundSecondary))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layerCornerRadius = Constants.Size.CornerRadiusMid
        
        backgroundColor = Constants.Color.BackgroundPrimary
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
        }
        
        icon.backgroundColor = .clear
        contentView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(platform: String, hideIcon: Bool = false) {
        titleLabel.text = platform
        icon.isHidden = hideIcon
    }
}
