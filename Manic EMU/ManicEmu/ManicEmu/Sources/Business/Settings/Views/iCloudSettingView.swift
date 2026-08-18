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
            view.backgroundColor = R.Color.BackgroundSecondary
            view.layerCornerRadius = R.Size.CornerRadiusMedium
            return view
        }()
        
        var enableSwitchButton: DisabledTapSwitch = {
            let view = DisabledTapSwitch()
            view.onTintColor = R.Color.Main
            view.tintColor = R.Color.BackgroundTertiary
            return view
        }()
        
        private let storageLabel: UILabel = {
            let view = UILabel()
            view.font = R.Font.Caption()
            view.textColor = R.Color.LabelSecondary
            return view
        }()
        
        private lazy var storageView: UIView = {
            let view = UIView()
            
            let titleContainerView = UIView()
            view.addSubview(titleContainerView)
            titleContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(R.Size.ContentSpaceTiny)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightSmall)
            }
            
            let titleLabel = UILabel()
            titleLabel.text = R.string.localizable.iCloudUsage()
            titleLabel.font = R.Font.Footnote(emphasis: true)
            titleLabel.textColor = R.Color.LabelSecondary
            titleContainerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let storageContainer = UIView()
            storageContainer.backgroundColor = R.Color.BackgroundSecondary
            storageContainer.layerCornerRadius = R.Size.CornerRadiusMedium
            view.addSubview(storageContainer)
            storageContainer.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(titleContainerView.snp.bottom)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            let storageIconView = UIImageView()
            storageIconView.contentMode = .center
            storageIconView.layerCornerRadius = 6
            storageIconView.image = UIImage(symbol: .opticaldiscdriveFill, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
            storageIconView.backgroundColor = R.Color.BackgroundTertiary.forceStyle(.dark)
            storageContainer.addSubview(storageIconView)
            storageIconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.size.equalTo(R.Size.IconSizeLarge)
                make.centerY.equalToSuperview()
            }
            
            let storageTitleLabel = UILabel()
            storageTitleLabel.text = R.string.localizable.usage()
            storageTitleLabel.textColor = R.Color.LabelPrimary
            storageTitleLabel.font = R.Font.Body(emphasis: true)
            storageContainer.addSubview(storageTitleLabel)
            storageTitleLabel.snp.makeConstraints { make in
                make.centerY.equalTo(storageIconView)
                make.leading.equalTo(storageIconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            }
            
            storageContainer.addSubview(storageLabel)
            storageLabel.snp.makeConstraints { make in
                make.centerY.equalTo(storageIconView)
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            view.isHidden = true
            return view
        }()
        
        private let detailLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 0
            view.text = R.string.localizable.iCloudDesc()
            view.font = R.Font.Caption()
            view.textColor = R.Color.LabelSecondary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let titleContainerView = UIView()
            addSubview(titleContainerView)
            titleContainerView.snp.makeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightSmall)
            }
            titleContainerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.centerY.trailing.equalToSuperview()
            }
            
            addSubview(enableContainer)
            enableContainer.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(titleContainerView.snp.bottom)
                make.height.equalTo(R.Size.ItemHeightLarge)
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
            enableIconView.image = UIImage(symbol: symbol, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
            enableIconView.backgroundColor = R.Color.Indigo
            enableContainer.addSubview(enableIconView)
            enableIconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.size.equalTo(R.Size.IconSizeLarge)
                make.centerY.equalToSuperview()
            }
            
            let enableTitleLabel = UILabel()
            enableTitleLabel.text = R.string.localizable.iCloudTitle()
            enableTitleLabel.textColor = R.Color.LabelPrimary
            enableTitleLabel.font = R.Font.Body(emphasis: true)
            enableContainer.addSubview(enableTitleLabel)
            enableTitleLabel.snp.makeConstraints { make in
                make.centerY.equalTo(enableIconView)
                make.leading.equalTo(enableIconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            }
            
            enableContainer.addSubview(enableSwitchButton)
            enableSwitchButton.snp.makeConstraints { make in
                make.centerY.equalTo(enableIconView)
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                if #available(iOS 26.0, tvOS 26.0, *) {
                    make.size.equalTo(CGSize(width: 63, height: 28))
                } else {
                    make.size.equalTo(CGSize(width: 51, height: 31))
                }
            }
            if #available(iOS 26.0, tvOS 26.0, *) {} else {
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
                make.top.equalTo(enableContainer.snp.bottom).offset(R.Size.ContentSpaceSmall)
            }
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setDatas() {
            var matt = NSMutableAttributedString(string: "")
            var detail = R.string.localizable.iCloudNotEnable()
            var color = R.Color.LabelSecondary
            if Settings.defalut.iCloudSyncEnable && PurchaseManager.isMember {
                if SyncManager.shared.syncState == .idle {
                    detail = R.string.localizable.iCloudSynced()
                    color = R.Color.Green
                } else if SyncManager.shared.syncState == .syncing {
                    detail = R.string.localizable.iCloudSyncing()
                    color = R.Color.Yellow
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
                    make.top.equalTo(enableContainer.snp.bottom).offset(R.Size.ContentSpaceSmall)
                }
            }
            
            enableSwitchButton.isEnabled = PurchaseManager.isMember
            
            matt.append(NSAttributedString(string: "●", attributes: [.font: R.Font.Caption(), .foregroundColor: color, .baselineOffset: 1]))
            matt.append(NSAttributedString(string: " " + detail, attributes: [.font: R.Font.Footnote(emphasis: true), .foregroundColor: color]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
            titleLabel.attributedText = matt
        }
    }
    
    private lazy var navigationView: ASNavigationView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.iCloudTitle(),
                                                                 titleIcon: .symbolImage(R.image.icloudsync_iconSymbols()))
        navigation.enableClose = showClose
        let view = ASNavigationView(navigation)
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.hide()
        }
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
        view.isFocusable = true
        view.contentInset = .insets(bottom: UIDevice.isPad ? (R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge) : R.Size.ContentInsetBottom)
        return view
    }()
    
    private let showClose: Bool
    private var iCloudDriveSyncChangeNotification: Any? = nil
    
    deinit {
        if let iCloudDriveSyncChangeNotification {
            NotificationCenter.default.removeObserver(iCloudDriveSyncChangeNotification)
        }
    }
    
    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            if showClose {
                make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            } else {
                make.top.equalToSuperview().offset(R.Size.ContentInsetTop)
            }
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        iCloudDriveSyncChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.iCloudDriveSyncChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.collectionView.reloadData()
        }
    }
    
    convenience init(showClose: Bool = true) {
        self.init(parameters: showClose)!
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
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: 0,
                                                            trailing: R.Size.ContentSpaceMedium)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)
            
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

extension ICloudSettingView: ShowableView {
    
}
