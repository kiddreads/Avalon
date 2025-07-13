//
//  BaseView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class BaseView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
