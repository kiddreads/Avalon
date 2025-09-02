//
//  ImportServiceListCollectionViewCell.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import TKSwitcherCollection

class ImportServiceListCollectionViewCell: UICollectionViewCell {
    private var iconView: UIImageView = {
        let view = UIImageView()
        return view
    }()
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }()
    
    var switchButton: TKSimpleSwitch = {
        let view = TKSimpleSwitch()
        view.onColor = Constants.Color.Main
        view.offColor = Constants.Color.BackgroundTertiary
        view.lineColor = .clear
        view.lineSize = 0
        view.alpha = 0
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
        enableInteractive = true
        delayInteractiveTouchEnd = true
        backgroundColor = Constants.Color.BackgroundPrimary
        layerCornerRadius = Constants.Size.CornerRadiusMax

        addSubviews([iconView, titleLabel, switchButton])
        
        iconView.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.Size.ContentSpaceHuge)
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.bottom.lessThanOrEqualTo(iconView.snp.top).offset(-Constants.Size.ContentSpaceUltraTiny)
        }
        
        switchButton.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.height.equalTo(28)
            make.width.equalTo(46)
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
    
    //TODO: 需要处理图片的尺寸
    func setData(service: ImportService) {
        
        iconView.image = service.iconImage
        
        var matt = NSMutableAttributedString(string: service.title, attributes: [.font: Constants.Font.title(size: .s, weight: .semibold), .foregroundColor: Constants.Color.LabelPrimary])
        if let detail = service.detail {
            matt.append(NSAttributedString(string: "\n" + detail, attributes: [.font: Constants.Font.body(), .foregroundColor: Constants.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        titleLabel.attributedText = matt
        
        if service.type == .wifi {
            switchButton.alpha = 1
            switchButton.setOn(WebServer.shard.isRunning, animate: false)
        } else {
            switchButton.alpha = 0
            switchButton.setOn(false, animate: false)
        }
    }
    
}
