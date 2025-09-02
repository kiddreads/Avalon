//
//  GameEditToolBar.swift
//  ManicEmu
//
//  Created by Max on 2025/1/31.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

enum GameEditToolItem: SettingCellItem, CaseIterable {
    case rename, cover, skin, shareRom, checkSave, importSave, shareSave, delete
    var image: UIImage {
        switch self {
        case .rename:
                .symbolImage(.highlighter)
        case .cover:
                .symbolImage(.photo)
        case .skin:
                .symbolImage(.tshirt)
        case .shareRom:
                .symbolImage(.squareAndArrowUp)
        case .checkSave:
                .symbolImage(.trayFull)
        case .importSave:
                .symbolImage(.trayAndArrowDown)
        case .shareSave:
                .symbolImage(.trayAndArrowUp)
        case .delete:
            UIImage(symbol: .trash, color: Constants.Color.Red)
        }
    }
    
    var title: String {
        switch self {
        case .rename:
            R.string.localizable.gamesRename()
        case .cover:
            R.string.localizable.gamesModifyCover()
        case .skin:
            R.string.localizable.gamesSpecifySkin()
        case .shareRom:
            R.string.localizable.gamesShareRom()
        case .checkSave:
            R.string.localizable.gamesCheckSave()
        case .importSave:
            R.string.localizable.gamesImportSave()
        case .shareSave:
            R.string.localizable.gamesShareSave()
        case .delete:
            R.string.localizable.gamesDelete()
        }
    }
    
    static var singleGameEditItems: [GameEditToolItem] {
        GameEditToolItem.allCases
    }
    
    static var multiGamesEditItems: [GameEditToolItem] {
        [.shareRom, .shareSave, .delete]
    }
    
    var enableLongPress: Bool { false }
}

class GameEditToolBar: RoundAndBorderView {
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: SettingItemCollectionViewCell.self)
        view.dataSource = self
        view.delegate = self
        view.bounces = false
        view.scrollsToTop = false
        return view
    }()
    
    private var singleSelectDatas = GameEditToolItem.singleGameEditItems
    private var multiSelectDatas = GameEditToolItem.multiGamesEditItems
    
    var isSingleGame: Bool = true {
        didSet {
            collectionView.reloadData()
        }
    }
    
    var didSelectItem: ((_ item: GameEditToolItem)->Void)?
    
    init() {
        super.init(roundCorner: [.topLeft, .topRight])
        makeBlur()
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self = self else { return nil }
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(Constants.Size.ItemHeightHuge),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .absolute(Constants.Size.ItemHeightHuge)),
                                                           subitem: item, count: self.isSingleGame ? 4 : 3)
            if #available(iOS 17.0, *) {
                group.interItemSpacing = NSCollectionLayoutSpacing.flexible(self.isSingleGame ? Constants.Size.ContentSpaceMin : 38)
            } else {
                group.interItemSpacing = NSCollectionLayoutSpacing.fixed(self.isSingleGame ? Constants.Size.ContentSpaceMin : 38)
            }
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = self.isSingleGame ? Constants.Size.ContentSpaceMin : 38
            section.contentInsets = NSDirectionalEdgeInsets(top: Constants.Size.ContentSpaceMid, leading: self.isSingleGame ? Constants.Size.ContentSpaceMid : 38, bottom: Constants.Size.ContentSpaceHuge, trailing: self.isSingleGame ? Constants.Size.ContentSpaceMid : 38)
            return section
            
        }
        return layout
    }
}

extension GameEditToolBar: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (isSingleGame ? singleSelectDatas : multiSelectDatas).count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SettingItemCollectionViewCell.self, for: indexPath)
        let item = (isSingleGame ? singleSelectDatas : multiSelectDatas)[indexPath.row]
        cell.setData(item: item)
        if item == .delete {
            cell.titleLabel.textColor = Constants.Color.Red
        } else {
            cell.titleLabel.textColor = Constants.Color.LabelSecondary
        }
        return cell
    }
}

extension GameEditToolBar: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectItem?((isSingleGame ? singleSelectDatas : multiSelectDatas)[indexPath.row])
    }
}
