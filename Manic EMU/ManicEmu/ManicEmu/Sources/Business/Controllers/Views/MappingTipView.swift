//
//  MappingTipView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import ManicEmuCore

class MappingTipView: UIView {
    class MappingBubbleView: RoundAndBorderView {
        var titleLabel: UILabel = {
            let view = UILabel()
            view.textColor = Constants.Color.LabelPrimary
            view.font = Constants.Font.body()
            view.textAlignment = .center
            return view
        }()
        
        override init(roundCorner: UIRectCorner = [], radius: CGFloat = Constants.Size.CornerRadiusMax, borderColor: UIColor = Constants.Color.Border, borderWidth: CGFloat = 1) {
            super.init(roundCorner: roundCorner, radius: radius, borderColor: borderColor, borderWidth: borderWidth)
            addShadow()
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(Constants.Size.ContentSpaceTiny)
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func updateTip(kind: ControllerSkin.Item.Kind, inputString: String?, position: CGPoint) {
        if let inputString {
            let bubbleView = MappingBubbleView(roundCorner: .allCorners, radius: Constants.Size.ItemHeightTiny/2)
            bubbleView.backgroundColor = Constants.Color.BackgroundPrimary
            addSubview(bubbleView)
            bubbleView.titleLabel.text = inputString
            var bubbleWidth = bubbleView.sizeThatFits(.init(100)).width + Constants.Size.ContentSpaceTiny*2
            bubbleWidth = bubbleWidth < Constants.Size.ItemHeightMid ? Constants.Size.ItemHeightMid : bubbleWidth
            
            bubbleView.snp.makeConstraints { make in
                make.height.equalTo(Constants.Size.ItemHeightTiny)
                make.width.greaterThanOrEqualTo(Constants.Size.ItemHeightMid)
                if kind == .button {
                    var centerX = position.x - self.width/2
                    if position.x - bubbleWidth/2 < 0 {
                        //左侧超过屏幕外
                        centerX -= (position.x - bubbleWidth/2)
                    } else if position.x + bubbleWidth/2 > self.width {
                        //右侧超过屏幕外
                        centerX -= (position.x + bubbleWidth/2 - self.width)
                    }
                    make.centerX.equalToSuperview().offset(centerX)
                    make.centerY.equalToSuperview().offset(position.y - self.height/2 - Constants.Size.ItemHeightTiny)
                } else {
                    make.centerX.equalToSuperview().offset(position.x - self.width/2)
                    make.centerY.equalToSuperview().offset(position.y - self.height/2)
                }
            }
        }
    }
}
