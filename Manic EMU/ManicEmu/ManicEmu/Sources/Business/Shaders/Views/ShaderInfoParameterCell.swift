//
//  ShaderInfoParameterCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ShaderInfoParameterCell: UICollectionViewCell {
    var titleLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelPrimary
        return label
    }()
    
    var chevronButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .chevronRight,
                                               font: Constants.Font.caption(size: .l, weight: .bold),
                                               color: Constants.Color.BackgroundSecondary),
                                title: "",
                                titleFont: Constants.Font.caption(size: .l),
                                titleColor: Constants.Color.LabelSecondary,
                                titleAlignment: .left,
                                edgeInsets: .init(inset: Constants.Size.ContentSpaceUltraTiny),
                                titlePosition: .left,
                                imageAndTitlePadding: Constants.Size.ContentSpaceUltraTiny,
                                enableGlass: false)
        view.backgroundColor = .clear
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enableInteractive = true
        delayInteractiveTouchEnd = true
        
        backgroundColor = Constants.Color.BackgroundPrimary
        layerCornerRadius = Constants.Size.CornerRadiusMid
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
        
        addSubview(chevronButton)
        chevronButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
