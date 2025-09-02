//
//  SettingsListFooterCollectionReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import StoreKit

class SettingsListFooterCollectionReusableView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        
        containerView.addTapGesture { gesture in
            UIApplication.shared.open(Constants.URLs.AppReview)
        }
        
        containerView.backgroundColor = Constants.Color.BackgroundPrimary
        containerView.layerCornerRadius = Constants.Size.ContentSpaceMax
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.Size.ContentSpaceHuge)
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
        
        let descLabelLeft = UILabel()
        descLabelLeft.textColor = Constants.Color.LabelPrimary
        descLabelLeft.font = Constants.Font.body(size: .l, weight: .semibold)
        descLabelLeft.text = R.string.localizable.ratingTitleLeft()
        containerView.addSubview(descLabelLeft)
        descLabelLeft.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.top.equalToSuperview().offset(Constants.Size.ContentSpaceMin)
        }
        
        let appNameImage = GradientImageView(image: R.image.app_title()?.scaled(toSize: CGSize(width: 100, height: 8.2)))
        containerView.addSubview(appNameImage)
        appNameImage.snp.makeConstraints { make in
            make.leading.equalTo(descLabelLeft.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalTo(descLabelLeft)
        }
        
        let descLabelRight = UILabel()
        descLabelRight.textColor = Constants.Color.LabelPrimary
        descLabelRight.font = Constants.Font.body(size: .l, weight: .semibold)
        descLabelRight.text = R.string.localizable.ratingTitleRight()
        containerView.addSubview(descLabelRight)
        descLabelRight.snp.makeConstraints { make in
            make.leading.equalTo(appNameImage.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalTo(appNameImage)
        }
        
        let detalLabel = UILabel()
        detalLabel.numberOfLines = 0
        detalLabel.textColor = Constants.Color.LabelSecondary
        detalLabel.font = Constants.Font.caption(size: .l)
        detalLabel.text = R.string.localizable.ratingDetail()
        containerView.addSubview(detalLabel)
        detalLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(appNameImage.snp.bottom).offset(Constants.Size.ContentSpaceUltraTiny)
        }
        
        let starContainer = UIView()
        (0..<5).forEach { index in
            let starView = UIImageView(image: UIImage(symbol: .starFill, font: Constants.Font.body(size: .l, weight: .medium), color: UIColor(hexString: "#FFC546")!))
            starView.contentMode = .center
            starContainer.addSubview(starView)
            starView.snp.makeConstraints { make in
                make.size.equalTo(Constants.Size.IconSizeMin)
                make.top.bottom.equalToSuperview()
                if index == 0 {
                    make.leading.equalToSuperview()
                } else {
                    
                    make.leading.equalTo(starContainer.subviews[index-1].snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
                }
                if index == 4 {
                    make.trailing.equalToSuperview()
                }
                make.bottom.equalToSuperview()
            }
        }
        containerView.addSubview(starContainer)
        starContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(detalLabel.snp.bottom).offset(6)
            make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceMin)
        }
        
        let seperator = SparkleSeperatorView()
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalTo(containerView).inset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(16)
            make.top.equalTo(containerView.snp.bottom).offset(40)
        }
        
        let bottomAppNameImage = UIImageView(image: R.image.app_title()?.withRenderingMode(.alwaysTemplate))
        bottomAppNameImage.tintColor = Constants.Color.LabelTertiary
        addSubview(bottomAppNameImage)
        bottomAppNameImage.snp.makeConstraints { make in
            make.top.equalTo(seperator.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
        }
        
        let versionLabel = UILabel()
        versionLabel.textColor = Constants.Color.LabelTertiary
        versionLabel.font = Constants.Font.caption(size: .m)
        versionLabel.text = "Version \(Constants.Config.AppVersion)"
        addSubview(versionLabel)
        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(bottomAppNameImage.snp.bottom).offset(7)
            make.centerX.equalToSuperview()
        }
        
        let starView = UIImageView(image: UIImage(symbol: .sparkle, color: Constants.Color.BackgroundPrimary))
        addSubview(starView)
        starView.snp.makeConstraints { make in
            make.top.equalTo(versionLabel.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
        }
        
        let lilyView = UIImageView(image: R.image.lily())
        addSubview(lilyView)
        lilyView.snp.makeConstraints { make in
            make.top.equalTo(starView.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
