//
//  FilterCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class FilterCollectionViewCell: UICollectionViewCell {
    
    var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layerCornerRadius = Constants.Size.CornerRadiusMin
        return view
    }()
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.font = Constants.Font.body()
        view.textColor = Constants.Color.LabelPrimary
        view.textAlignment = .center
        return view
    }()
    
    private var selectImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.layerCornerRadius = Constants.Size.CornerRadiusMin
        view.layer.shadowColor = Constants.Color.Shadow.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 2
        view.image = UIImage(symbol: .checkmarkCircleFill, weight: .bold, colors: [Constants.Color.LabelPrimary, Constants.Color.Main])
        view.alpha = 0
        return view
    }()
    
    override var isSelected: Bool {
        willSet {
            UIView.springAnimate {
                self.selectImageView.alpha = newValue ? 1 : 0
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enableInteractive = true
        delayInteractiveTouchEnd = true
        layerCornerRadius = Constants.Size.CornerRadiusMid
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(-Constants.Size.ItemHeightMin)
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(Constants.Size.ContentSpaceMin)
        }
        
        addSubview(selectImageView)
        selectImageView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceTiny)
            make.size.equalTo(Constants.Size.IconSizeMin)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(image: UIImage?, title: String) {
        imageView.image = image
        titleLabel.text = title
    }
}
