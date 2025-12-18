//
//  ShaderInfoAppendCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ShaderInfoAppendCell: UICollectionViewCell {
    private var iconView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = Constants.Color.Main
        view.contentMode = .center
        view.layerCornerRadius = 6
        view.image = UIImage(symbol: .timer, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        return view
    }()
    
    private var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        let matt = NSMutableAttributedString(string: R.string.localizable.appendShadersTitle(), attributes: [.font: Constants.Font.body(size: .l, weight: .semibold), .foregroundColor: Constants.Color.LabelPrimary])
        matt.append(NSAttributedString(string: "\n\(R.string.localizable.appendShadersDetail())", attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: Constants.Color.LabelSecondary]))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
        style.alignment = .left
        label.attributedText = matt.applying(attributes: [.paragraphStyle: style])
        return label
    }()
    
    var chevronButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .chevronRight,
                                               font: Constants.Font.caption(size: .l, weight: .bold),
                                               color: Constants.Color.BackgroundSecondary),
                                title: "",
                                titleFont: Constants.Font.caption(size: .l),
                                titleColor: Constants.Color.LabelSecondary,
                                titleAlignment: .left,
                                edgeInsets: .init(inset: Constants.Size.ContentSpaceUltraTiny),
                                titlePosition: .left,
                                imageAndTitlePadding: Constants.Size.ContentSpaceUltraTiny,
                                enableGlass: false)
        view.backgroundColor = .clear
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enableInteractive = true
        delayInteractiveTouchEnd = true
        
        backgroundColor = Constants.Color.BackgroundPrimary
        layerCornerRadius = Constants.Size.CornerRadiusMid
        
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(18)
            make.leading.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(24)
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
        }
        
        addSubview(chevronButton)
        chevronButton.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
