//
//  TitleDetailChevronCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class TitleDetailChevronCollectionCell: UICollectionViewCell {
    var titleLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelPrimary
        return label
    }()
    
    var chevronButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .chevronRight,
                                               font: Constants.Font.caption(size: .l, weight: .bold),
                                               color: Constants.Color.BackgroundSecondary),
                                title: "",
                                titleFont: Constants.Font.body(size: .s),
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
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
        
        addSubview(chevronButton)
        chevronButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(title: String, detail: String) {
        titleLabel.text = title
        chevronButton.titleLabel.text = detail
    }
    
}
