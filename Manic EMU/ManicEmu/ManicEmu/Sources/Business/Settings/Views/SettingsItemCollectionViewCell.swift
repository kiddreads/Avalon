//
//  SettingsItemCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import TKSwitcherCollection

class SettingsItemCollectionViewCell: UICollectionViewCell {
    private var iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.layerCornerRadius = 6
        return view
    }()
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 3
        return view
    }()
    
    var chevronIconView: UIImageView = {
        let view = UIImageView(image: UIImage(symbol: .chevronRight, font: Constants.Font.caption(size: .l, weight: .bold), color: Constants.Color.BackgroundTertiary))
        view.isHidden = true
        view.contentMode = .center
        return view
    }()
    
    var switchButton: TKSimpleSwitch = {
        let view = TKSimpleSwitch()
        view.isHidden = true
        view.onColor = Constants.Color.Main
        view.offColor = Constants.Color.BackgroundTertiary
        view.lineColor = .clear
        view.lineSize = 0
        return view
    }()
    
    private var arrowDetailLabel: UILabel = {
        let view = UILabel()
        view.font = Constants.Font.caption()
        view.textColor = Constants.Color.LabelSecondary
        view.isHidden = true
        return view
    }()
    
    private var mainColorChangeNotification: Any? = nil
    
    deinit {
        if let mainColorChangeNotification = mainColorChangeNotification {
            NotificationCenter.default.removeObserver(mainColorChangeNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().offset(-46-Constants.Size.ContentSpaceMid-Constants.Size.ContentSpaceMin)
        }
        
        addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(16)
        }
        
        addSubview(arrowDetailLabel)
        arrowDetailLabel.snp.makeConstraints { make in
            make.centerY.equalTo(chevronIconView)
            make.trailing.equalTo(chevronIconView.snp.leading).offset(-Constants.Size.ContentSpaceUltraTiny)
        }
        
        addSubview(switchButton)
        switchButton.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(CGSize(width: 46, height: 28))
        }
        
        mainColorChangeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.MainColorChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.switchButton.onColor = Constants.Color.Main
            self.switchButton.reload()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(item: SettingItem) {
        iconView.image = item.icon
        iconView.backgroundColor = item.backgroundColor
        var matt = NSMutableAttributedString(string: item.title, attributes: [.font: Constants.Font.body(size: .l, weight: .semibold), .foregroundColor: Constants.Color.LabelPrimary])
        if let detail = item.detail {
            matt.append(NSAttributedString(string: "\n" + detail, attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: Constants.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        titleLabel.attributedText = matt
        
        switch item.type {
        case .leftHand, .quickGame, .airPlay, .iCloud, .fullScreenWhenConnectController, .autoSaveState, .respectSilentMode:
            switchButton.isHidden = false
            chevronIconView.isHidden = true
            enableInteractive = false
            delayInteractiveTouchEnd = false
        default:
            switchButton.isHidden = true
            chevronIconView.isHidden = false
            enableInteractive = true
            delayInteractiveTouchEnd = true
        }
        if let isOn = item.isOn {
            if !PurchaseManager.isMember && (item.type == .airPlay || item.type == .iCloud) {
                switchButton.customEnable = false
                switchButton.setOn(false, animate: false)
            } else {
                switchButton.customEnable = true
                switchButton.setOn(isOn, animate: false)
            }
        } else {
            switchButton.customEnable = false
            switchButton.setOn(false, animate: false)
        }
        
        switch item.type {
        case .clearCache, .language:
            arrowDetailLabel.isHidden = false
        default:
            arrowDetailLabel.isHidden = true
        }
        arrowDetailLabel.text = item.arrowDetail
    }
    
}
