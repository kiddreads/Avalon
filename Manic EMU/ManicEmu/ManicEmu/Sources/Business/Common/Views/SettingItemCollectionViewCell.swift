//
//  SettingItemCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/5.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class SettingItemCollectionViewCell: UICollectionViewCell {
    
    var iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()
    
    var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = Constants.Font.caption()
        view.textColor = Constants.Color.LabelSecondary
        view.textAlignment = .center
        view.adjustsFontSizeToFitWidth = true
        return view
    }()
    
    private var disableCover: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = .black.withAlphaComponent(0.4)
        view.layerCornerRadius = Constants.Size.CornerRadiusMid
        return view
    }()
    
    var editButton: UIView = {
        let view = UIView()
        view.layerCornerRadius = 10
        view.isHidden = true
        return view
    }()
    
    private var editIcon: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()
    
    private var longPressIcon: UIImageView = {
        let view = UIImageView(image: .init(symbol: .livephoto, color: Constants.Color.LabelSecondary))
        view.contentMode = .scaleAspectFit
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        enableInteractive = true
        delayInteractiveTouchEnd = true
        
        let roundAndBorderView = RoundAndBorderView(roundCorner: .allCorners, radius: Constants.Size.CornerRadiusMid)
        roundAndBorderView.makeBlur(blurColor: Constants.Color.BackgroundSecondary)
        addSubview(roundAndBorderView)
        roundAndBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let containerView = UIView()
        roundAndBorderView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        containerView.addSubviews([iconView, titleLabel])
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.top.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(Constants.Size.ContentSpaceUltraTiny/2)
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceUltraTiny)
            make.bottom.equalToSuperview()
        }
        
        addSubview(disableCover)
        disableCover.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(longPressIcon)
        longPressIcon.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeTiny)
            make.top.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceUltraTiny)
        }
        
        addSubview(editButton)
        editButton.snp.makeConstraints { make in
            make.size.equalTo(CGSize(20))
            make.trailing.equalToSuperview().offset(Constants.Size.ContentSpaceUltraTiny)
            make.top.equalToSuperview().offset(-Constants.Size.ContentSpaceUltraTiny)
        }
        
        editButton.addSubview(editIcon)
        editIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //TODO: 需要处理图片的尺寸
    func setData(item: SettingCellItem, editable: Bool = false, isPlus: Bool = false, enable: Bool = true, mappingMode: Bool = false) {
        if item.title == R.string.localizable.gameSettingQuit() {
            iconView.image = item.image.applySymbolConfig(color: Constants.Color.Red)
            titleLabel.textColor = Constants.Color.Red
        } else {
            iconView.image = item.image
            titleLabel.textColor = Constants.Color.LabelSecondary
        }
        titleLabel.text = item.title
        if editable {
            editButton.isHidden = false
            enableInteractive = false
        } else {
            editButton.isHidden = true
            enableInteractive = true
        }
        if isPlus {
            editIcon.image = UIImage(symbol: .plus, font: Constants.Font.caption(size: .l, weight: .medium))
            editButton.backgroundColor = Constants.Color.Green
        } else {
            editIcon.image = UIImage(symbol: .minus, font: Constants.Font.caption(size: .l, weight: .medium))
            editButton.backgroundColor = Constants.Color.Red
        }
        disableCover.isHidden = enable
        if !editable {
            longPressIcon.isHidden = !item.enableLongPress
        }
        if mappingMode {
            longPressIcon.isHidden = true
        }
    }
}
