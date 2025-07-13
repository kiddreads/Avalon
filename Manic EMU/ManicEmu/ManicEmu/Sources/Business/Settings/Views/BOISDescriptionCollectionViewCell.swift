//
//  BOISDescriptionCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/10.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class BOISDescriptionCollectionViewCell: UICollectionViewCell {
    private let descLabel: UILabel = {
        let desc = UILabel()
        desc.numberOfLines = 0
        desc.textColor = Constants.Color.LabelSecondary
        desc.font = Constants.Font.body()
        desc.text = R.string.localizable.biosAlert()
        return desc
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
