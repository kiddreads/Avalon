//
//  ImportFooterCollectionReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/23.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ImportFooterCollectionReusableView: UICollectionReusableView {
    var channelButton: UIView = {
        let view = UIView()
        view.enableInteractive = true
        view.delayInteractiveTouchEnd = true
        view.backgroundColor = Constants.Color.BackgroundPrimary
        view.layerCornerRadius = 15
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMid)
            make.leading.greaterThanOrEqualToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        
        let tipsIcon = UIImageView(image: UIImage(symbol: .lightbulb, size: 11, weight: .medium))
        tipsIcon.contentMode = .center
        tipsIcon.layerCornerRadius = Constants.Size.IconSizeMin.height/2
        tipsIcon.backgroundColor = UIColor(hexString: "#FFC546")
        containerView.addSubview(tipsIcon)
        tipsIcon.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeMin)
        }
        
        let descLabel = UILabel()
        descLabel.numberOfLines = 0
        var matt = NSMutableAttributedString(string: "Drag & Drop", attributes: [.font: Constants.Font.title(size: .s, weight: .semibold), .foregroundColor: Constants.Color.LabelPrimary])
        matt.append(NSAttributedString(string: "\n" + R.string.localizable.importDragAndDropTips(), attributes: [.font: Constants.Font.body(), .foregroundColor: Constants.Color.LabelSecondary]))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
        matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        descLabel.attributedText = matt
        
        containerView.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.centerY.equalTo(tipsIcon)
            make.leading.equalTo(tipsIcon.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview()
        }
        
        let seperator = SparkleSeperatorView()
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalTo(containerView).inset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(16)
            make.top.lessThanOrEqualTo(containerView.snp.bottom).offset(40)
        }
        
        addSubview(channelButton)
        channelButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(30)
            make.top.lessThanOrEqualTo(seperator.snp.bottom).offset(40)
            make.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        let channelLinkLabel = UILabel()
        channelLinkLabel.isUserInteractionEnabled = true
        channelLinkLabel.textAlignment = .center
        channelLinkLabel.adjustsFontSizeToFitWidth = true
        channelButton.addSubview(channelLinkLabel)
        channelLinkLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.centerY.equalToSuperview()
        }
        let channelName = Locale.prefersCN ? R.string.localizable.qqChannelName() : "Telegram"
        let matt2 = NSMutableAttributedString(string: R.string.localizable.importChannelTips(" \(channelName) "), attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: Constants.Color.LabelPrimary])
        channelLinkLabel.attributedText = matt2.applying(attributes: [.foregroundColor: Constants.Color.Main], toOccurrencesOf: channelName)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
