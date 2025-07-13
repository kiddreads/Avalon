//
//  GameViewExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore

private var airPlayViewKey = 0

extension GameView {
    var isAirPlaying: Bool {
        get { self.airPlayView != nil }
        set {
            guard newValue != self.isAirPlaying else { return }
            
            if newValue {
                self.showAirPlayView()
            } else {
                self.hideAirPlayView()
            }
        }
    }
    
    weak var airPlayView: UIView? {
        get { objc_getAssociatedObject(self, &airPlayViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &airPlayViewKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN) }
    }
    
    func showAirPlayView() {
        guard self.airPlayView == nil else { return }
        
        let placeholderView = UIView(frame: .zero)
        placeholderView.backgroundColor = .black
        
        let iconImageView = UIImageView(image: UIImage(symbol: .airplayvideo, size: Constants.Size.ItemHeightMid, color: Constants.Color.LabelSecondary))
        placeholderView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        let textLabel = UILabel()
        textLabel.font = Constants.Font.body()
        textLabel.textColor = Constants.Color.LabelSecondary
        textLabel.text = R.string.localizable.airPlayingTitle()
        placeholderView.addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
        }
        
        self.addSubview(placeholderView)
        placeholderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.airPlayView = placeholderView
    }
    
    func hideAirPlayView() {
        guard let airPlayView else { return }
        
        airPlayView.removeFromSuperview()
        
        self.airPlayView = nil
    }
}
