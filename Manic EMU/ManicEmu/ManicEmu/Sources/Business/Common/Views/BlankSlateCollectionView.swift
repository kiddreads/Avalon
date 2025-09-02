//
//  BlankSlateCollectionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import BlankSlate
import KeyboardKit

class BlankSlateEmptyView: UIView {
    let imageView = UIImageView()
    
    let label = UILabel()
    
    init(image: UIImage? = nil, title: String) {
        super.init(frame: .zero)
        
        imageView.image = image ?? R.image.empty_icon()
        imageView.contentMode = .center
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-Constants.Size.ItemHeightMin)
        }
        
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelSecondary
        label.text = title
        label.numberOfLines = 0
        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.Size.ContentSpaceMax)
            make.centerX.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class BlankSlateCollectionView: KeyboardCollectionView {
    
    var blankSlateView: UIView? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        Log.debug("\(String(describing: Self.self)) init")
        self.bs.setDataSourceAndDelegate(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BlankSlateCollectionView: BlankSlate.DataSource {
    func customView(forBlankSlate view: UIView) -> UIView? {
        return blankSlateView
    }
    
    func layout(forBlankSlate view: UIView, for element: BlankSlate.Element) -> BlankSlate.Layout {
        return .init(edgeInsets: .zero, height: Constants.Size.WindowHeight)
    }
    
}

extension BlankSlateCollectionView: BlankSlate.Delegate {
    
}
