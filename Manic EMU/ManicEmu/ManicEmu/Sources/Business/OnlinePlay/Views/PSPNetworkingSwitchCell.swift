//
//  PSPNetworkingSwitchCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PSPNetworkingSwitchCell: UICollectionViewCell {
    var enableSwitchButton: DisabledTapSwitch = {
        let view = DisabledTapSwitch()
        view.onTintColor = Constants.Color.Main
        view.tintColor = Constants.Color.BackgroundSecondary
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let enableContainer: UIView = {
            let view = UIView()
            view.backgroundColor = Constants.Color.BackgroundPrimary
            view.layerCornerRadius = Constants.Size.CornerRadiusMid
            return view
        }()
        
        addSubview(enableContainer)
        enableContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        let enableIconView = UIImageView()
        enableIconView.contentMode = .center
        enableIconView.layerCornerRadius = 6
        enableIconView.image = UIImage(symbol: .person2Wave2Fill, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        enableIconView.backgroundColor = Constants.Color.Red
        enableContainer.addSubview(enableIconView)
        enableIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.centerY.equalToSuperview()
        }
        
        let enableTitleLabel = UILabel()
        enableTitleLabel.text = R.string.localizable.enableNetworking()
        enableTitleLabel.textColor = Constants.Color.LabelPrimary
        enableTitleLabel.font = Constants.Font.body(size: .l, weight: .semibold)
        enableContainer.addSubview(enableTitleLabel)
        enableTitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(enableIconView)
            make.leading.equalTo(enableIconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
        }
        
        enableContainer.addSubview(enableSwitchButton)
        enableSwitchButton.snp.makeConstraints { make in
            make.centerY.equalTo(enableIconView)
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            if #available(iOS 26.0, *) {
                make.size.equalTo(CGSize(width: 63, height: 28))
            } else {
                make.size.equalTo(CGSize(width: 51, height: 31))
            }
        }
        if #available(iOS 26.0, *) {} else {
            enableSwitchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
