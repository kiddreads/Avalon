//
//  BlankSlateTableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import BlankSlate

class BlankSlateTableView: UITableView {
    var blankSlateView: UIView? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        Log.debug("\(String(describing: Self.self)) init")
        self.bs.setDataSourceAndDelegate(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BlankSlateTableView: BlankSlate.DataSource {
    func customView(forBlankSlate view: UIView) -> UIView? {
        return blankSlateView
    }
    
    func layout(forBlankSlate view: UIView, for element: BlankSlate.Element) -> BlankSlate.Layout {
        .init(edgeInsets: .zero, height: Constants.Size.WindowHeight)
    }
    
}

extension BlankSlateTableView: BlankSlate.Delegate {
    
}
