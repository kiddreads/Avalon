//
//  iCloudSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class ICloudSettingView: BaseView {
    
    class ICloudSettingViewCell: UICollectionViewCell {
        private let titleLabel: UILabel = {
            let view = UILabel()
            return view
        }()
        
        private let enableContainer: UIView = {
            let view = UIView()
            view.backgroundColor = Constants.Color.BackgroundPrimary
            view.layerCornerRadius = Constants.Size.CornerRadiusMid
            return view
        }()
        
        var enableSwitchButton: DisabledTapSwitch = {
            let view = DisabledTapSwitch()
            view.onTintColor = Constants.Color.Main
            view.tintColor = Constants.Color.BackgroundSecondary
            return view
        }()
        
        private let storageLabel: UILabel = {
            let view = UILabel()
            view.font = Constants.Font.caption(size: .l)
            view.textColor = Constants.Color.LabelSecondary
            return view
        }()
        
        private lazy var storageView: UIView = {
            let view = UIView()
            
            let titleContainerView = UIView()
            view.addSubview(titleContainerView)
            titleContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(Constants.Size.ContentSpaceUltraTiny)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(Constants.Size.ItemHeightMin)
            }
            
            let titleLabel = UILabel()
            titleLabel.text = R.string.localizable.iCloudUsage()
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
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            let storageIconView = UIImageView()
            storageIconView.contentMode = .center
            storageIconView.layerCornerRadius = 6
            storageIconView.image = UIImage(symbol: .opticaldiscdriveFill, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
            storageIconView.backgroundColor = Constants.Color.BackgroundSecondary.forceStyle(.dark)
            storageContainer.addSubview(storageIconView)
            storageIconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                make.size.equalTo(Constants.Size.IconSizeMid)
                make.centerY.equalToSuperview()
            }
            
            let storageTitleLabel = UILabel()
            storageTitleLabel.text = R.string.localizable.usage()
            storageTitleLabel.textColor = Constants.Color.LabelPrimary
            storageTitleLabel.font = Constants.Font.body(size: .l, weight: .semibold)
            storageContainer.addSubview(storageTitleLabel)
            storageTitleLabel.snp.makeConstraints { make in
                make.centerY.equalTo(storageIconView)
                make.leading.equalTo(storageIconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            }
            
            storageContainer.addSubview(storageLabel)
            storageLabel.snp.makeConstraints { make in
                make.centerY.equalTo(storageIconView)
                make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
            
            view.isHidden = true
            return view
        }()
        
        private let detailLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 0
            view.text = R.string.localizable.iCloudDesc()
            view.font = Constants.Font.caption(size: .l)
            view.textColor = Constants.Color.LabelSecondary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let titleContainerView = UIView()
            addSubview(titleContainerView)
            titleContainerView.snp.makeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(Constants.Size.ItemHeightMin)
            }
            titleContainerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.centerY.trailing.equalToSuperview()
            }
            
            addSubview(enableContainer)
            enableContainer.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(titleContainerView.snp.bottom)
                make.height.equalTo(Constants.Size.ItemHeightMax)
            }
            
            let enableIconView = UIImageView()
            enableIconView.contentMode = .center
            enableIconView.layerCornerRadius = 6
            let symbol: SFSymbol
            if #available(iOS 17.0, *) {
                symbol = .arrowTriangle2CirclepathIcloudFill
            } else {
                symbol = .cloudFill
            }
            enableIconView.image = UIImage(symbol: symbol, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
            enableIconView.backgroundColor = Constants.Color.Blue
            enableContainer.addSubview(enableIconView)
            enableIconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                make.size.equalTo(Constants.Size.IconSizeMid)
                make.centerY.equalToSuperview()
            }
            
            let enableTitleLabel = UILabel()
            enableTitleLabel.text = R.string.localizable.iCloudTitle()
            enableTitleLabel.textColor = Constants.Color.LabelPrimary
            enableTitleLabel.font = Constants.Font.body(size: .l, weight: .semibold)
            enableContainer.addSubview(enableTitleLabel)
            enableTitleLabel.snp.makeConstraints { make in
                make.centerY.equalTo(enableIconView)
                make.leading.equalTo(enableIconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            }
            
            enableContainer.addSubview(enableSwitchButton)
            enableSwitchButton.snp.makeConstraints { make in
                make.centerY.equalTo(enableIconView)
                make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                if #available(iOS 26.0, *) {
                    make.size.equalTo(CGSize(width: 63, height: 28))
                } else {
                    make.size.equalTo(CGSize(width: 51, height: 31))
                }
            }
            if #available(iOS 26.0, *) {} else {
                enableSwitchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
            }
            
            addSubview(storageView)
            storageView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(enableContainer.snp.bottom)
                make.height.equalTo(108)
            }
            
            addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(enableContainer.snp.bottom).offset(Constants.Size.ContentSpaceMin)
            }
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setDatas() {
            var matt = NSMutableAttributedString(string: "")
            var detail = R.string.localizable.iCloudNotEnable()
            var color = Constants.Color.LabelSecondary
            if Settings.defalut.iCloudSyncEnable && PurchaseManager.isMember {
                if SyncManager.shared.syncState == .idle {
                    detail = R.string.localizable.iCloudSynced()
                    color = Constants.Color.Green
                } else if SyncManager.shared.syncState == .syncing {
                    detail = R.string.localizable.iCloudSyncing()
                    color = Constants.Color.Yellow
                }
                
                enableSwitchButton.setOn(true, animated: true)
                
                storageView.isHidden = false
                
                if let iCloudPath = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.path {
                    storageLabel.text = FileType.humanReadableFileSize(CacheManager.folderSize(atPath: iCloudPath)) ?? "-"
                } else {
                    storageLabel.text = "-"
                }
                
                detailLabel.snp.updateConstraints { make in
                    make.top.equalTo(enableContainer.snp.bottom).offset(120)
                }
            } else {
                enableSwitchButton.setOn(false, animated: true)
                storageView.isHidden = true
                detailLabel.snp.updateConstraints { make in
                    make.top.equalTo(enableContainer.snp.bottom).offset(Constants.Size.ContentSpaceMin)
                }
            }
            
            enableSwitchButton.isEnabled = PurchaseManager.isMember
            
            matt.append(NSAttributedString(string: "●", attributes: [.font: Constants.Font.caption(size: .m), .foregroundColor: color, .baselineOffset: 1]))
            matt.append(NSAttributedString(string: " " + detail, attributes: [.font: Constants.Font.body(size: .s, weight: .semibold), .foregroundColor: color]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
            titleLabel.attributedText = matt
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
        view.register(cellWithClass: ICloudSettingViewCell.self)
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
    
    private var iCloudDriveSyncChangeNotification: Any? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
        if let iCloudDriveSyncChangeNotification {
            NotificationCenter.default.removeObserver(iCloudDriveSyncChangeNotification)
        }
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
        
        let symbol: SFSymbol
        if #available(iOS 17.0, *) {
            symbol = .arrowTriangle2CirclepathIcloudFill
        } else {
            symbol = .cloudFill
        }
        let icon = UIImageView(image: UIImage(symbol: symbol, font: Constants.Font.body(weight: .bold)))
        icon.contentMode = .scaleAspectFit
        topBlurView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = R.string.localizable.iCloudTitle()
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
        
        iCloudDriveSyncChangeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.iCloudDriveSyncChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.collectionView.reloadData()
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
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(280)), subitems: [item])
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

extension ICloudSettingView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: ICloudSettingViewCell.self, for: indexPath)
        cell.setDatas()
        cell.enableSwitchButton.onChange { [weak cell, weak self] value in
            //icloud设置
            if value {
                UIView.makeAlert(title: R.string.localizable.iCloudTipsTitle(),
                                 detail: R.string.localizable.iCloudTipsDetail(),
                                 confirmTitle: R.string.localizable.iCloudConfirm(), cancelAction: { [weak cell] in
                    cell?.enableSwitchButton.setOn(false, animated: true)
                }, confirmAction: {
                    Settings.defalut.iCloudSyncEnable = value
                    if value, let iCloudServiceEnable = SyncManager.shared.iCloudServiceEnable, !iCloudServiceEnable {
                        //尝试开启iCloud 但是目前iCloud服务不可用 弹出一个提示
                        UIView.makeAlert(title: R.string.localizable.iCloudDisableTitle(), detail: R.string.localizable.iCloudDisableDetail(), cancelTitle: R.string.localizable.confirmTitle())
                    }
                    self?.collectionView.reloadData()
                }, tapBackgroundAction: {
                    cell?.enableSwitchButton.setOn(false, animated: true)
                })
            } else {
                Settings.defalut.iCloudSyncEnable = value
                self?.collectionView.reloadData()
            }
        }
        cell.enableSwitchButton.onDisableTap {
            topViewController()?.present(PurchaseViewController(featuresType: .iCloud), animated: true)
        }
         
        
        return cell
    }
}

extension ICloudSettingView: UICollectionViewDelegate {
    
}

