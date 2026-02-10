//
//  PSPNetworkingConfigCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import BetterSegmentedControl

class PSPNetworkingConfigCell: UICollectionViewCell {
    private lazy var segmentView: BetterSegmentedControl = {
        let segments = LabelSegment.segments(withTitles: [R.string.localizable.lanNetworking(), R.string.localizable.wanNetworking()],
                                             normalFont: Constants.Font.body(),
                                             normalTextColor: Constants.Color.LabelSecondary,
                                             selectedTextColor: Constants.Color.LabelPrimary)
        let options: [BetterSegmentedControl.Option] = [
            .backgroundColor(Constants.Color.Background),
            .indicatorViewInset(5),
            .indicatorViewBackgroundColor(Constants.Color.BackgroundPrimary),
            .cornerRadius(16)
        ]
        let view = BetterSegmentedControl(frame: .zero,
                                          segments: segments,
                                          options: options)
        
        view.on(.valueChanged) { [weak self] sender, forEvent in
            guard let self, let index = (sender as? BetterSegmentedControl)?.index else { return }
            UIDevice.generateHaptic()
            self.didTypeChange?(index == 0 ? .local : .online)
        }
        return view
    }()
    
    private lazy var localNerworkingView: PSPNetworkingConfigLocalView = {
        let view = PSPNetworkingConfigLocalView()
        view.didAsHostChange = { [weak self] asHost in
            self?.didAsHostChange?(asHost)
        }
        view.didPortChange = { [weak self] port in
            self?.didPortChange?(port)
        }
        view.didConnectedIPChange = { [weak self] connectedIP in
            self?.didConnectedIPChange?(connectedIP)
        }
        view.isHidden = true
        return view
    }()
    
    private lazy var onlineNerworkingView: PSPNetworkingConfigOnlineView = {
        let view = PSPNetworkingConfigOnlineView()
        view.didConnectedHostChange = { [weak self] connectedHost in
            self?.didConnectedHostChange?(connectedHost)
        }
        view.isHidden = true
        return view
    }()
    
    var didTypeChange: ((PSPNetworkingConfig.ConfigType)->Void)? = nil
    var didAsHostChange: ((Bool)->Void)? = nil
    var didPortChange: ((Int32)->Void)? = nil
    var didConnectedHostChange: ((String?)->Void)? = nil
    var didConnectedIPChange: ((String?)->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = Constants.Size.CornerRadiusMax
        containerView.backgroundColor = Constants.Color.BackgroundPrimary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        containerView.addSubview(localNerworkingView)
        localNerworkingView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(segmentView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
        }
        
        containerView.addSubview(onlineNerworkingView)
        onlineNerworkingView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(segmentView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(config: PSPNetworkingConfig) {
        segmentView.setIndex(config.type == .local ? 0 : 1)
        if config.type == .local {
            localNerworkingView.isHidden = false
            onlineNerworkingView.isHidden = true
            localNerworkingView.setData(config: config)
        } else {
            localNerworkingView.isHidden = true
            onlineNerworkingView.isHidden = false
            onlineNerworkingView.setData(config: config)
        }
    }
    
    static func CellHeight(config: PSPNetworkingConfig) -> Double {
        var configHeight: CGFloat = 0
        if config.type == .local {
            if config.asHost {
                configHeight = 146
            } else {
                let serviceItemCount = config.hostList.count
                let serviceListHeight = 50*CGFloat(serviceItemCount) + 20*(CGFloat(serviceItemCount)-1) + 10
                configHeight = 60 + 48 + 60 + 48 + (serviceListHeight > 0 ? serviceListHeight : 0)
            }
        } else {
            configHeight = 60
        }
        return 16 + 50 + 20 + configHeight + 24
    }
}
