//
//  GameSavePurchaseGuideReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/17.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class GameSavePurchaseGuideReusableView: UICollectionReusableView {
    
    var guideView: GameSavePurchaseGuideView = {
        let view = GameSavePurchaseGuideView(hideSeperator: false)
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(guideView)
        guideView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
