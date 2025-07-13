//
//  ControllersCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit
import ManicEmuCore
import MarqueeLabel

class ControllersCollectionViewCell: UICollectionViewCell {
    private var iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()
    
    private var titleLabel: MarqueeLabel = {
        let view = MarqueeLabel()
        view.font = Constants.Font.body(size: .l, weight: .semibold)
        view.textColor = Constants.Color.LabelPrimary
        view.type = .leftRight
        return view
    }()
    
    var contextMenuButton: ContextMenuButton = {
        let view = ContextMenuButton()
        return view
    }()
    
    var selectButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .chevronUpChevronDown, font: Constants.Font.caption(weight: .bold)),
                                title: R.string.localizable.controllersPlayerUnset(),
                                titleFont: Constants.Font.body(),
                                edgeInsets: .zero,
                                titlePosition: .left,
                                imageAndTitlePadding: Constants.Size.ContentSpaceUltraTiny)
        view.layerCornerRadius = 0
        view.delayInteractiveTouchEnd = true
        view.backgroundColor = .clear
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Constants.Color.Background
        layerCornerRadius = Constants.Size.CornerRadiusMid

        addSubviews([iconView, titleLabel, selectButton])
        
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeMin)
        }
        
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceTiny)
            make.centerY.equalToSuperview()
        }
        
        selectButton.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(Constants.Size.ContentSpaceTiny)
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
        }
        
        insertSubview(contextMenuButton, belowSubview: selectButton)
        contextMenuButton.snp.makeConstraints { make in
            make.edges.equalTo(selectButton)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(controller: GameController) {
        iconView.image = controller.image
        titleLabel.text = controller.name
        if let playerIndex = controller.playerIndex {
            selectButton.titleLabel.text = R.string.localizable.controllersPlayerIndex(playerIndex+1)
            selectButton.titleLabel.textColor = Constants.Color.LabelPrimary
        } else {
            selectButton.titleLabel.text = R.string.localizable.controllersPlayerUnset()
            selectButton.titleLabel.textColor = Constants.Color.LabelSecondary
        }
    }
}
