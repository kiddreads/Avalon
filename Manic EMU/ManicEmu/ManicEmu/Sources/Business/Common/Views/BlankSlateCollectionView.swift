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

class BlankSlateEmptyView: UIView {
    init(title: String) {
        super.init(frame: .zero)
        
        let imageView = UIImageView(image: R.image.empty_icon())
        imageView.contentMode = .center
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-Constants.Size.ItemHeightMin)
        }
        
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelSecondary
        label.text = title
        label.numberOfLines = 0
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

class BlankSlateCollectionView: UICollectionView {
    
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
        .init(edgeInsets: .zero, height: Constants.Size.WindowHeight)
    }
    
}

extension BlankSlateCollectionView: BlankSlate.Delegate {
    
}
