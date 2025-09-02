//
//  SymbolButton.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import UIKit

class SymbolButton: UIView {
    private let containerView = UIView()
    
    lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()
    
    let titleLabel = UILabel()
    
    var enableRoundCorner: Bool = false {
        didSet {
            if enableRoundCorner {
                layer.cornerRadius = height/2
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if enableRoundCorner {
            layer.cornerRadius = height/2
        }
    }
    
    convenience init(symbol: SFSymbol,
                     title: String,
                     titleFont: UIFont = Constants.Font.caption(),
                     titleColor: UIColor = Constants.Color.LabelPrimary,
                     titleAlignment: NSTextAlignment = .center,
                     edgeInsets: UIEdgeInsets? = nil,
                     horizontalContian: Bool = false,
                     titlePosition: UITextLayoutDirection = .down,
                     imageAndTitlePadding: CGFloat = Constants.Size.ContentSpaceUltraTiny) {
        self.init(image: .symbolImage(symbol), title: title, titleFont: titleFont, titleColor: titleColor, titleAlignment: titleAlignment, edgeInsets: edgeInsets, horizontalContian: horizontalContian, titlePosition: titlePosition, imageAndTitlePadding: imageAndTitlePadding)
    }
    
    init(image: UIImage?,
         title: String,
         titleFont: UIFont = Constants.Font.caption(),
         titleColor: UIColor = Constants.Color.LabelPrimary,
         titleAlignment: NSTextAlignment = .center,
         edgeInsets: UIEdgeInsets? = nil,
         horizontalContian: Bool = false,
         titlePosition: UITextLayoutDirection = .down,
         imageAndTitlePadding: CGFloat = Constants.Size.ContentSpaceUltraTiny) {
        super.init(frame: .zero)
        enableInteractive = true
        backgroundColor = Constants.Color.BackgroundSecondary
        layerCornerRadius = Constants.Size.CornerRadiusMid
        
        addSubview(containerView)
        containerView.addSubviews([imageView, titleLabel])
        
        containerView.snp.makeConstraints { make in
            if let edgeInsets = edgeInsets {
                make.leading.equalToSuperview().inset(edgeInsets.left)
                make.top.equalToSuperview().inset(edgeInsets.top)
                make.trailing.equalToSuperview().inset(edgeInsets.right)
                make.bottom.equalToSuperview().inset(edgeInsets.bottom)
            } else {
                make.center.equalToSuperview()
            }
            if horizontalContian {
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
            }
        }
        
        imageView.snp.makeConstraints { make in
            switch titlePosition {
            case .right:
                make.leading.top.bottom.equalToSuperview()
                make.width.greaterThanOrEqualTo(0)
            case .left:
                make.trailing.top.bottom.equalToSuperview()
                make.width.greaterThanOrEqualTo(0)
            case .up:
                make.leading.trailing.bottom.equalToSuperview()
            case .down:
                make.leading.top.trailing.equalToSuperview()
            default:
                break
            }
        }
        imageView.image = image
        
        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        titleLabel.textAlignment = titleAlignment
        titleLabel.snp.makeConstraints { make in
            switch titlePosition {
            case .right:
                make.top.trailing.bottom.equalToSuperview()
                make.leading.equalTo(imageView.snp.trailing).offset(imageAndTitlePadding)
            case .left:
                make.top.leading.bottom.equalToSuperview()
                make.trailing.equalTo(imageView.snp.leading).offset(-imageAndTitlePadding)
            case .up:
                make.top.trailing.leading.equalToSuperview()
                make.bottom.equalTo(imageView.snp.top).offset(-imageAndTitlePadding)
            case .down:
                make.leading.trailing.bottom.equalToSuperview()
                make.top.equalTo(imageView.snp.bottom).offset(imageAndTitlePadding)
            default:
                break
            }
            
        }
        titleLabel.text = title
    }
    
    convenience init(symbol: SFSymbol) {
        self.init(image: .symbolImage(symbol))
    }
    
    init(image: UIImage?) {
        super.init(frame: .zero)
        enableInteractive = true
        backgroundColor = Constants.Color.BackgroundSecondary
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        imageView.image = image
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func triggerTapGesture() {
        for gestureRecognizer in gestureRecognizers ?? [] {
            if let tapGesture = gestureRecognizer as? UITapGestureRecognizer {
                tapGesture.state = .ended
            }
        }
    }
}
