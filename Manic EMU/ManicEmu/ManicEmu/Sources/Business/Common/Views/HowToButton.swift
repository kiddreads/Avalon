//
//  HowToButton.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class HowToButton: UIView {
    var label: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.font = Constants.Font.caption(size: .l)
        view.textColor = Constants.Color.Main
        return view
    }()
    
    init(title: String, tapGesture: (()->Void)?) {
        super.init(frame: .zero)
        backgroundColor = Constants.Color.BackgroundSecondary
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
        }
       enableInteractive = true
        label.text = title
        addTapGesture { gesture in
            tapGesture?()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layerCornerRadius = height/2
    }
}
