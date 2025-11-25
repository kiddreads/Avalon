//
//  JITSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import Device

class JITSettingView: BaseView {
    
    class JITSettingViewCell: UICollectionViewCell {
        private let jitView: UIView = {
            let view = UIView()
            
            let container = UIView()
            container.backgroundColor = Constants.Color.BackgroundPrimary
            container.layerCornerRadius = Constants.Size.CornerRadiusMid
            view.addSubview(container)
            container.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            let iconView = UIImageView()
            iconView.contentMode = .center
            iconView.layerCornerRadius = 6
            iconView.image = UIImage(symbol: .boltFill, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
            iconView.backgroundColor = Constants.Color.Indigo
            container.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                make.size.equalTo(Constants.Size.IconSizeMid)
                make.centerY.equalToSuperview()
            }
            
            let jitLabel = UILabel()
            let jitEnable = LibretroCore.jitAvailable()
            jitLabel.text = jitEnable ? R.string.localizable.jitAllow() : R.string.localizable.jitNotAllow()
            jitLabel.textColor = jitEnable ? Constants.Color.Green : Constants.Color.Red
            jitLabel.font = Constants.Font.body(size: .l, weight: .semibold)
            container.addSubview(jitLabel)
            jitLabel.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            }
            
            return view
        }()
        
        private lazy var deviceView: UIView = {
            let view = UIView()
            
            let titleContainerView = UIView()
            view.addSubview(titleContainerView)
            titleContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(Constants.Size.ContentSpaceUltraTiny)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(Constants.Size.ItemHeightMin)
            }
            
            let titleLabel = UILabel()
            titleLabel.text = R.string.localizable.device()
            titleLabel.font = Constants.Font.body(size: .s, weight: .semibold)
            titleLabel.textColor = Constants.Color.LabelSecondary
            titleContainerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let storageContainer = UIView()
            storageContainer.backgroundColor = Constants.Color.BackgroundPrimary
            storageContainer.layerCornerRadius = Constants.Size.CornerRadiusMid
            view.addSubview(storageContainer)
            storageContainer.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(titleContainerView.snp.bottom)
                make.height.equalTo(240)
            }
            
            func genItemView(symbol: SFSymbol, title: String, detail: String) -> UIView {
                let containerView = UIView()
                
                let iconView = UIImageView()
                iconView.contentMode = .center
                iconView.layerCornerRadius = 6
                iconView.image = UIImage(symbol: symbol, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
                iconView.backgroundColor = Constants.Color.LabelTertiary.forceStyle(.dark)
                containerView.addSubview(iconView)
                iconView.snp.makeConstraints { make in
                    make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                    make.size.equalTo(Constants.Size.IconSizeMid)
                    make.centerY.equalToSuperview()
                }
                
                let titleLabel = UILabel()
                titleLabel.text = title
                titleLabel.textColor = Constants.Color.LabelPrimary
                titleLabel.font = Constants.Font.body(size: .l, weight: .semibold)
                containerView.addSubview(titleLabel)
                titleLabel.snp.makeConstraints { make in
                    make.centerY.equalTo(iconView)
                    make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                }
                
                let detailLabel = UILabel()
                detailLabel.text = detail
                detailLabel.textColor = Constants.Color.LabelSecondary
                detailLabel.font = Constants.Font.caption(size: .l)
                containerView.addSubview(detailLabel)
                detailLabel.snp.makeConstraints { make in
                    make.centerY.equalTo(iconView)
                    make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMin)
                }
                return containerView
            }
            
            //Install Source
            var sourceDetail = ""
            #if SIDE_LOAD
            sourceDetail = "Sideload"
            #else
            sourceDetail = "AppStore"
            #endif
            let sourceView = genItemView(symbol: .appFill, title: R.string.localizable.installSource(), detail: sourceDetail)
            storageContainer.addSubview(sourceView)
            sourceView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            
            //Device
            let deviceView = genItemView(symbol: .iphone, title: R.string.localizable.device(), detail: Device.version().rawValue)
            storageContainer.addSubview(deviceView)
            deviceView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(sourceView.snp.bottom)
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            //System
            let v = ProcessInfo.processInfo.operatingSystemVersion
            let systemView = genItemView(symbol: .squareStack3dUpFill, title: R.string.localizable.system(), detail: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)")
            storageContainer.addSubview(systemView)
            systemView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(deviceView.snp.bottom)
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            //Memory
            let memoryBytes = ProcessInfo.processInfo.physicalMemory
            let memoryView = genItemView(symbol: .memorychipFill, title: R.string.localizable.memory(), detail: FileType.humanReadableFileSize(memoryBytes, numeralSystem: 1000, decimalPlaces: 0) ?? "Unknown")
            storageContainer.addSubview(memoryView)
            memoryView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(systemView.snp.bottom)
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            return view
        }()
        
        private let installSideloadView: UIView = {
            let view = UIView()
            view.enableInteractive = true
            view.delayInteractiveTouchEnd = true
            view.addTapGesture { gesture in
                if UIApplication.shared.canOpenURL(Constants.URLs.InstallSideload) {
                    UIApplication.shared.open(Constants.URLs.InstallSideload)
                } else {
                    UIApplication.shared.open(Constants.URLs.SideStore)
                }
            }
            
            let container = UIView()
            container.backgroundColor = Constants.Color.BackgroundPrimary
            container.layerCornerRadius = Constants.Size.CornerRadiusMid
            view.addSubview(container)
            container.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            let iconView = UIImageView()
            iconView.contentMode = .center
            iconView.layerCornerRadius = 6
            iconView.image = R.image.customArrowTriangleheadSwap()?.applySymbolConfig(font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
            iconView.backgroundColor = Constants.Color.Background.forceStyle(.dark)
            container.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                make.size.equalTo(Constants.Size.IconSizeMid)
                make.centerY.equalToSuperview()
            }
            
            let label = UILabel()
            label.text = R.string.localizable.installSideloadVersion()
            label.textColor = Constants.Color.LabelPrimary
            label.font = Constants.Font.body(size: .l, weight: .semibold)
            container.addSubview(label)
            label.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            }
            
            let chevronIconView = UIImageView(image: UIImage(symbol: .chevronRight, font: Constants.Font.caption(size: .l, weight: .bold), color: Constants.Color.BackgroundSecondary))
            chevronIconView.contentMode = .center
            container.addSubview(chevronIconView)
            chevronIconView.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
            
            return view
        }()
        
        private let detailLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 0
            view.text = R.string.localizable.jitDesc()
            view.font = Constants.Font.caption(size: .l)
            view.textColor = Constants.Color.LabelSecondary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        
            addSubview(jitView)
            jitView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            addSubview(deviceView)
            deviceView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(jitView.snp.bottom)
                make.height.equalTo(288)
            }
            
            var detailOffset = 0
            #if SIDE_LOAD
            detailOffset = 12
            #else
            detailOffset = 92
            
            addSubview(installSideloadView)
            installSideloadView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(deviceView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            #endif
            
            addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(deviceView.snp.bottom).offset(detailOffset)
            }
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let topBlurView: UIView = {
        let view = UIView()
        view.makeBlur()
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: JITSettingViewCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = UIEdgeInsets(top: Constants.Size.ItemHeightMid, left: 0, bottom: UIDevice.isPad ? (Constants.Size.ContentInsetBottom + Constants.Size.HomeTabBarSize.height + Constants.Size.ContentSpaceMax) : Constants.Size.ContentInsetBottom, right: 0)
        return view
    }()
    
    private lazy var closeButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .xmark, font: Constants.Font.body(weight: .bold)), enableGlass: true)
        view.enableRoundCorner = true
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.didTapClose?()
        }
        return view
    }()
    
    ///点击关闭按钮回调
    var didTapClose: (()->Void)? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    init(showClose: Bool = true) {
        super.init(frame: .zero)
        Log.debug("\(String(describing: Self.self)) init")
        backgroundColor = Constants.Color.Background
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(topBlurView)
        topBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        let icon = UIImageView(image: UIImage(symbol: .boltFill, font: Constants.Font.body(weight: .bold)))
        icon.contentMode = .scaleAspectFit
        topBlurView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = "JIT"
        headerTitleLabel.textColor = Constants.Color.LabelPrimary
        headerTitleLabel.font = Constants.Font.title(size: .s)
        topBlurView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalTo(icon)
        }
        
        if showClose {
            topBlurView.addSubview(closeButton)
            closeButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(600)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: Constants.Size.ContentSpaceMid,
                                                            bottom: 0,
                                                            trailing: Constants.Size.ContentSpaceMid)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: Constants.Size.ContentSpaceMin, trailing: 0)
            
            return section
        }
        return layout
    }
}

extension JITSettingView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: JITSettingViewCell.self, for: indexPath)
        return cell
    }
}

extension JITSettingView: UICollectionViewDelegate {
    
}
