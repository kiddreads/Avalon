//
//  IconView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/18.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class IconView: UIView {
    var image: UIImage? = nil {
        didSet {
            imageView.image = image
        }
    }
    
    let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        masksToBounds = true
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
