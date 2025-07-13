//
//  GameSaveEmptyCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class GameSaveEmptyCollectionViewCell: UICollectionViewCell {
    
    private let container = UIView()
    
    private var guideView: GameSavePurchaseGuideView = {
        let view = GameSavePurchaseGuideView(hideSeperator: true)
        view.isHidden = true
        return view
    }()
    
    private let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(container)
        container.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.center.equalToSuperview()
        }

        imageView.image = R.image.empty_icon()
        container.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        
        container.addSubview(guideView)
        guideView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom)
        }
        
    }
    
    func setGuideViewHidden(_ hidden: Bool) {
        guideView.isHidden = hidden
        container.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.center.equalToSuperview()
        }
        if hidden {
            guideView.snp.removeConstraints()
            imageView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.centerX.equalToSuperview()
            }
        } else {
            imageView.snp.remakeConstraints { make in
                make.top.centerX.equalToSuperview()
            }
            guideView.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.bottom.equalToSuperview()
                make.top.equalTo(imageView.snp.bottom)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
