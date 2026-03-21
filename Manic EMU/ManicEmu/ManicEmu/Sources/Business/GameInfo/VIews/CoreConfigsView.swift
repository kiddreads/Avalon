//
//  CoreConfigsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/19.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import ManicEmuCore
import ProHUD

class CoreConfigsView: BaseView {
    
    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur()
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: CoreConfigsCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: BackgroundColorHaderReusableView.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: BackgroundColorDetailFooterReusableView.self)
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
            if self.originalUserConfigs != self.userConfigs {
                if let jsonString = self.userConfigs?.jsonString() {
                    self.game.updateExtra(key: ExtraKey.coreConfigs.rawValue, value: jsonString)
                } else {
                    self.game.updateExtra(key: ExtraKey.coreConfigs.rawValue, value: nil)
                }
            }
            self.didTapClose?()
        }
        return view
    }()
    
    private lazy var moreContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.configsResetCore()) { [weak self] _ in
            guard let self = self else { return }
            //reset to core default
            self.reset(toCoreDefault: true)
        }))
        actions.append((UIAction(title: R.string.localizable.configsResetBefore()) { [weak self] _ in
            guard let self = self else { return }
            //reset to user config
            self.reset(toCoreDefault: false)
        }))
        let view = ContextMenuButton(image: nil, menu: UIMenu(children: actions))
        return view
    }()
    
    private lazy var moreButton: SymbolButton = {
        let view = SymbolButton(symbol: .ellipsis, enableGlass: true)
        view.enableRoundCorner = true
        view.addTapGesture { [weak self] gesture in
            self?.moreContextMenuButton.triggerTapGesture()
        }
        return view
    }()
    
    ///点击关闭按钮回调
    var didTapClose: (()->Void)? = nil
    var didConfigChange: (([String: String])->Void)? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    var game: Game
    private var coreOptionCategories: [CoreOptionCategory] = []
    private var originalUserConfigs: [String: String]?
    private var userConfigs: [String: String]?
    
    
    init(game: Game) {
        self.game = game
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

        let icon = UIImageView(image: game.gameType.coreConfigIcon?.applySymbolConfig(size: 30))
        icon.contentMode = .scaleAspectFit
        navigationBlurView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = game.gameType.coreConfigTitle
        headerTitleLabel.textColor = Constants.Color.LabelPrimary
        headerTitleLabel.font = Constants.Font.title(size: .s)
        navigationBlurView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalTo(icon)
        }
        
        navigationBlurView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
        }
        
        navigationBlurView.addSubview(moreContextMenuButton)
        moreContextMenuButton.snp.makeConstraints { make in
            make.trailing.equalTo(closeButton.snp.leading).offset(-Constants.Size.ContentSpaceMid)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
        }
        
        navigationBlurView.addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.edges.equalTo(moreContextMenuButton)
        }
        
        UIView.makeLoading()
        DispatchQueue.main.asyncAfter(delay: 0.35, execute: { [weak self] in
            guard let self else { return }
            if let json = game.getStoreCoreConfigs() {
                originalUserConfigs = json
                userConfigs = json
            }
            if let corePath = game.libretroCorePath,
                let coreCategories = LibretroCore.sharedInstance().getOptions(corePath) {
                coreOptionCategories = coreCategories
            }
            self.collectionView.reloadData()
            UIView.hideLoading()
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .estimated(Constants.Size.ItemHeightMax)))

            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(Constants.Size.ItemHeightMax)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: Constants.Size.ContentSpaceMid,
                                                            bottom: 0,
                                                            trailing: Constants.Size.ContentSpaceMid)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: Constants.Size.ContentSpaceMin, trailing: 0)
            
            //header布局
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(44)),
                                                                         elementKind: UICollectionView.elementKindSectionHeader,
                                                                         alignment: .top)
            headerItem.pinToVisibleBounds = true
            section.boundarySupplementaryItems = [headerItem]
            
            //footer
            let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .estimated(44)),
                                                                         elementKind: UICollectionView.elementKindSectionFooter,
                                                                         alignment: .bottom)
            section.boundarySupplementaryItems.append(footerItem)
            
            //decoration
            section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: CoreConfigsCollectionReusableView.self))]
            
            return section
        }
        
        layout.register(CoreConfigsCollectionReusableView.self, forDecorationViewOfKind: String(describing: CoreConfigsCollectionReusableView.self))
        return layout
    }
    
    class CoreConfigsCollectionReusableView: UICollectionReusableView {
        var backgroundView: UIView = {
            let view = UIView()
            view.layerCornerRadius = Constants.Size.CornerRadiusMax
            view.backgroundColor = Constants.Color.BackgroundPrimary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(Constants.Size.ItemHeightMin)
                make.bottom.equalToSuperview().offset(-32)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private func modifyConfig(key: String, value: String?) {
        var tempConfig = userConfigs ?? [:]
        tempConfig[key] = value
        if tempConfig.count == 0 {
            userConfigs = nil
        } else {
            userConfigs = tempConfig
        }
        collectionView.reloadData()
    }
    
    private func getOptionValue(coreOption: CoreOption) -> String {
        return getOption(coreOption: coreOption).value
    }
    
    private func getOptionLabel(coreOption: CoreOption) -> String {
        return getOption(coreOption: coreOption).label
    }
    
    private func getOption(coreOption: CoreOption) -> Options {
        if let userConfigs,
           let userValue = userConfigs[coreOption.key],
            let option = coreOption.options.first(where: { $0.value == userValue }) {
            return option
        }
        if let defaultOption = coreOption.options.first(where: { $0.value == coreOption.value }) {
            return defaultOption
        }
        let option = Options()
        option.value = coreOption.value
        option.label = ""
        return option
    }
    
    private func reset(toCoreDefault: Bool) {
        if toCoreDefault {
            userConfigs = nil
        } else {
            userConfigs = originalUserConfigs
        }
        collectionView.reloadData()
    }
}

extension CoreConfigsView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return coreOptionCategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return coreOptionCategories[section].options.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: CoreConfigsCell.self, for: indexPath)
        let coreOption = coreOptionCategories[indexPath.section].options[indexPath.row]
        cell.setData(title: coreOption.desc, detail: getOptionLabel(coreOption: coreOption))
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorHaderReusableView.self, for: indexPath)
            header.titleLabel.text = coreOptionCategories[indexPath.section].title
            return header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorDetailFooterReusableView.self, for: indexPath)
            footer.titleLabel.text = coreOptionCategories[indexPath.section].info + "\n"
            return footer
        }
    }
}

extension CoreConfigsView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let coreOption = coreOptionCategories[indexPath.section].options[indexPath.row]
        CoreConfigsOptionView.show(coreOption: coreOption, defaultOption: getOption(coreOption: coreOption), optionChange: { [weak self] value in
            guard let self else { return }
            self.modifyConfig(key: coreOption.key, value: value)
            self.didConfigChange?([coreOption.key: value])
        })
    }
}

extension CoreConfigsView {
    static var isShow: Bool {
        Sheet.find(identifier: String(describing: CoreConfigsView.self)).count > 0 ? true : false
    }
    
    static func show(game: Game, hideCompletion: (()->Void)? = nil, configChange: (([String: String])->Void)? = nil) {
        Sheet.lazyPush(identifier: String(describing: CoreConfigsView.self)) { sheet in
            sheet.configGamePlayingStyle(hideCompletion: hideCompletion)
            
            let view = UIView()
            let containerView = RoundAndBorderView(roundCorner: (UIDevice.isPad || UIDevice.isLandscape || PlayViewController.menuInsets != nil) ? .allCorners : [.topLeft, .topRight])
            containerView.backgroundColor = Constants.Color.Background
            view.addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                if let maxHeight = sheet.config.cardMaxHeight {
                    make.height.equalTo(maxHeight)
                }
            }
            view.addPanGesture { [weak view, weak sheet] gesture in
                guard let view = view, let sheet = sheet else { return }
                let point = gesture.translation(in: gesture.view)
                view.transform = .init(translationX: 0, y: point.y <= 0 ? 0 : point.y)
                if gesture.state == .recognized {
                    let v = gesture.velocity(in: gesture.view)
                    if (view.y > view.height*2/3 && v.y > 0) || v.y > 1200 {
                        // 达到移除的速度
                        sheet.pop()
                    }
                    UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .curveEaseOut], animations: {
                        view.transform = .identity
                    })
                }
            }
            
            let coreConfigsView = CoreConfigsView(game: game)
            coreConfigsView.didTapClose = { [weak sheet] in
                sheet?.pop()
            }
            coreConfigsView.didConfigChange = { configChange?($0) }
            containerView.addSubview(coreConfigsView)
            coreConfigsView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            sheet.set(customView: view).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
}

class CoreConfigsCell: UICollectionViewCell {
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }()
    
    private var chevronIconView: UIImageView = {
        let view = UIImageView(image: UIImage(symbol: .chevronRight, font: Constants.Font.caption(size: .l, weight: .bold), color: Constants.Color.BackgroundSecondary))
        view.contentMode = .center
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enableInteractive = true
        delayInteractiveTouchEnd = true
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.trailing.equalToSuperview().inset(38)
        }
        
        addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(title: String, detail: String) {
        let matt = NSMutableAttributedString(string: title, attributes: [.font: Constants.Font.body(size: .l), .foregroundColor: Constants.Color.LabelPrimary])
        matt.append(NSAttributedString(string: "\n\(detail)", attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: Constants.Color.LabelSecondary]))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
        style.alignment = .left
        titleLabel.attributedText = matt.applying(attributes: [.paragraphStyle: style])
    }
}

