//
//  GlobalCoreSwitchView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import ManicEmuCore
import IceCream
import RealmSwift

class GlobalCoreSwitchView: BaseView {
    
    private let datas: [GameType]
    private var globalCoreConfig: GlobalCoreSwitch
    
    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur()
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: TitleDetailChevronCollectionCell.self)
        view.register(cellWithClass: SettingDescriptionCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: MultiLineBackgroundColorHaderReusableView.self)
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
        self.datas = System.allCases.map({ $0.gameType }).filter({ $0.supportCores.count > 0 })
        self.globalCoreConfig = GlobalCoreSwitch.getConfig()
        super.init(frame: .zero)
        Log.debug("\(String(describing: Self.self)) init")
        backgroundColor = Constants.Color.Background
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(navigationBlurView)
        navigationBlurView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        let icon = UIImageView(image: R.image.customGearshape()?.applySymbolConfig())
        navigationBlurView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = R.string.localizable.globalCoreSwitch()
        headerTitleLabel.textColor = Constants.Color.LabelPrimary
        headerTitleLabel.font = Constants.Font.title(size: .s)
        navigationBlurView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalTo(icon)
        }
        
        if showClose {
            navigationBlurView.addSubview(closeButton)
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
                                                                                 heightDimension: sectionIndex == 0 ? .estimated(100) : .fractionalHeight(1)))
            
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: sectionIndex == 0 ? .estimated(100) : .absolute(Constants.Size.ItemHeightMax)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: Constants.Size.ContentSpaceMid,
                                                            bottom: 0,
                                                            trailing: Constants.Size.ContentSpaceMid)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: Constants.Size.ContentSpaceMin, trailing: 0)
            
            if sectionIndex != 0 {
                section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: PlatformSelectionView.PlatformSelectionCollectionReusableView.self))]
            }
            
            return section
        }
        layout.register(PlatformSelectionView.PlatformSelectionCollectionReusableView.self, forDecorationViewOfKind: String(describing: PlatformSelectionView.PlatformSelectionCollectionReusableView.self))
        return layout
    }
}

extension GlobalCoreSwitchView: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return datas.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: SettingDescriptionCollectionViewCell.self, for: indexPath)
            cell.descLabel.text = R.string.localizable.globalCoreSwitchDesc()
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: TitleDetailChevronCollectionCell.self, for: indexPath)
            let gameType = datas[indexPath.row]
            cell.setData(title: gameType.localizedShortName, detail: globalCoreConfig.getUsingCoreName(gameType: gameType) ?? "")
            return cell
        }
    }
}

extension GlobalCoreSwitchView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section != 0 else { return }
        let gameType = datas[indexPath.row]
        let supportCores = gameType.supportCores.filter({ !$0.isEmpty })
        OptionsChooseView.show(options: supportCores,
                               title:  R.string.localizable.switchEmulationCore(),
                               detail: R.string.localizable.switchEmulationCoreDetail(gameType.localizedShortName),
                               completion: { [weak self] index in
            guard let self else { return }
            if let index {
                let coreName = supportCores[index]
                self.globalCoreConfig.setUsingCoreName(gameType: gameType, coreName: coreName)
                self.collectionView.reloadData()
                let realm = Database.realm
                let games = realm.objects(Game.self).where({ $0.gameType == gameType })
                if games.count > 0 {
                    UIView.makeAlert(title: R.string.localizable.allCoreSwitch(),
                                     detail: R.string.localizable.allCoreSwitchDesc(gameType.localizedShortName, coreName),
                                     confirmTitle: R.string.localizable.confirmTitle(), confirmAction: {
                        games.forEach({
                            if !($0.isAzaharArticBase || $0.isArticBaseHomeMenu) {
                                $0.changeDefaultCore(coreIndex: index)
                            }
                        })
                    })
                }
            }
        })
    }
}
