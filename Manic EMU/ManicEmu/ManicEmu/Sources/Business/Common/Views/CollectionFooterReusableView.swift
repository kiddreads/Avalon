//
//  CollectionFooterReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class BackgroundColorDetailFooterReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = Constants.Color.LabelSecondary
        view.font = Constants.Font.caption(size: .l)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel])
        
        titleLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMax)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
