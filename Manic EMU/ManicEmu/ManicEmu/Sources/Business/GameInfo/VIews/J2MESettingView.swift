//
//  J2MESettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import IQKeyboardManagerSwift
import ProHUD


class J2MERotationSwitchCell: UICollectionViewCell {
    var enableSwitchButton: DisabledTapSwitch = {
        let view = DisabledTapSwitch()
        view.onTintColor = Constants.Color.Main
        view.tintColor = Constants.Color.BackgroundSecondary
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let enableContainer: UIView = {
            let view = UIView()
            view.backgroundColor = Constants.Color.BackgroundPrimary
            view.layerCornerRadius = Constants.Size.CornerRadiusMid
            return view
        }()
        
        addSubview(enableContainer)
        enableContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        let enableIconView = UIImageView()
        enableIconView.contentMode = .center
        enableIconView.layerCornerRadius = 6
        enableIconView.image = UIImage(symbol: .rotateLeft, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        enableIconView.backgroundColor = Constants.Color.Red
        enableContainer.addSubview(enableIconView)
        enableIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.centerY.equalToSuperview()
        }
        
        let enableTitleLabel = UILabel()
        enableTitleLabel.text = R.string.localizable.rotateScreen()
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class J2MEScreenSizeCell: UICollectionViewCell {
    
    var currentSize = J2MESize.defaultSize
    
    var didSetScreenSize: ((J2MESize)->Void)? = nil
    
    private lazy var widthTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = Constants.Color.LabelSecondary
        textField.font = Constants.Font.caption(size: .l)
        textField.placeholder = R.string.localizable.width()
        textField.keyboardType = .asciiCapableNumberPad
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.textAlignment = .center
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            if text.contains(".") {
                textField?.text = text.replacingOccurrences(of: ".", with: "")
            }
            if text.count > 3 {
                if let markRange = textField?.markedTextRange, let _ = textField?.position(from: markRange.start, offset: 0) { } else {
                    textField?.text = String(text.prefix(3))
                }
            }
            if let num = text.int, num > 800 {
                textField?.text = "800"
            }
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            self.updateSize(width: self.widthTextField.text?.int ?? self.currentSize.width, height: self.heightTextField.text?.int ?? self.currentSize.height)
        }
        return textField
    }()
    
    private lazy var heightTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = Constants.Color.LabelSecondary
        textField.font = Constants.Font.caption(size: .l)
        textField.placeholder = R.string.localizable.height()
        textField.keyboardType = .decimalPad
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.textAlignment = .center
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            if text.contains(".") {
                textField?.text = text.replacingOccurrences(of: ".", with: "")
            }
            if text.count > 3 {
                if let markRange = textField?.markedTextRange, let _ = textField?.position(from: markRange.start, offset: 0) { } else {
                    textField?.text = String(text.prefix(3))
                }
            }
            if let num = text.int, num > 800 {
                textField?.text = "800"
            }
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            self.updateSize(width: self.widthTextField.text?.int ?? self.currentSize.width, height: self.heightTextField.text?.int ?? self.currentSize.height)
        }
        return textField
    }()
    
    private lazy var screenSizeInputView: UIView = {
        let view = UIView()
        view.layerCornerRadius = Constants.Size.CornerRadiusMid
        view.backgroundColor = Constants.Color.Background
        
        let iconView = UIImageView()
        iconView.contentMode = .center
        iconView.layerCornerRadius = 6
        iconView.image = R.image.customArrowUpLeftAndArrowDownRightSquare()!.applySymbolConfig(font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        iconView.backgroundColor = Constants.Color.Main
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.centerY.equalToSuperview()
        }
        
        let titleLabel = UILabel()
        titleLabel.text = R.string.localizable.screenSize()
        titleLabel.textColor = Constants.Color.LabelPrimary
        titleLabel.font = Constants.Font.body(size: .l, weight: .semibold)
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
        }
        
        view.addSubview(widthTextField)
        widthTextField.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
        }
        
        let xLabel = UILabel()
        xLabel.text = "X"
        xLabel.textColor = Constants.Color.LabelSecondary
        xLabel.font = Constants.Font.caption(size: .l)
        view.addSubview(xLabel)
        xLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(widthTextField.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
        }
        
        view.addSubview(heightTextField)
        heightTextField.snp.makeConstraints { make in
            make.leading.equalTo(xLabel.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
        }
        
        let chevronIconView: UIImageView = {
            let view = UIImageView()
            view.image = UIImage(symbol: .ellipsisCircle, font: Constants.Font.body(size: .l, weight: .semibold), color: Constants.Color.BackgroundSecondary)
            return view
        }()
        
        var moreContextMenuButton: ContextMenuButton = {
            var screenSizes = Constants.Strings.J2MEScreenSizes + [R.string.localizable.custom()]
            var actions = [UIMenuElement]()
            for (index, sizeString) in screenSizes.enumerated() {
                actions.append((UIAction(title: sizeString) { [weak self] _ in
                    guard let self else { return }
                    if index == screenSizes.count - 1 {
                        if let text = self.widthTextField.text, text.isEmpty {
                            self.widthTextField.becomeFirstResponder()
                        } else if let text = self.heightTextField.text, text.isEmpty {
                            self.heightTextField.becomeFirstResponder()
                        } else {
                            self.widthTextField.becomeFirstResponder()
                        }
                    } else {
                        self.widthTextField.resignFirstResponder()
                        self.heightTextField.resignFirstResponder()
                        if let size = J2MESize(stringValue: sizeString) {
                            self.updateSize(width: size.width, height: size.height)
                        }
                    }
                }))
            }
            let view = ContextMenuButton(image: nil, menu: UIMenu(children: actions))
            return view
        }()
        
        view.addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(heightTextField.snp.trailing).offset(Constants.Size.ContentSpaceTiny)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(CGSize(width: 24, height: 24))
        }
        
        view.addSubview(moreContextMenuButton)
        moreContextMenuButton.snp.makeConstraints { make in
            make.leading.equalTo(chevronIconView)
            make.top.bottom.trailing.equalToSuperview()
        }
        
        return view
    }()
    
    private lazy var widthSliderView: AddTriggerButtonStyleCell.SliderView = {
        let view = AddTriggerButtonStyleCell.SliderView(title: R.string.localizable.width(), valueSufix: nil, minimumValue: 96, maximumValue: 800, numberOfDecimalPlaces: -1)
        view.didChangeEnd = { [weak self ] port in
            guard let self else { return }
            self.updateSize(width: port.int, height: currentSize.height)
        }
        return view
    }()
    
    private lazy var heightSliderView: AddTriggerButtonStyleCell.SliderView = {
        let view = AddTriggerButtonStyleCell.SliderView(title: R.string.localizable.height(), valueSufix: nil, minimumValue: 95, maximumValue: 800, numberOfDecimalPlaces: -1)
        view.didChangeEnd = { [weak self ] port in
            guard let self else { return }
            self.updateSize(width: currentSize.width, height: port.int)
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = Constants.Size.CornerRadiusMax
        containerView.backgroundColor = Constants.Color.BackgroundPrimary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(screenSizeInputView)
        screenSizeInputView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        containerView.addSubview(widthSliderView)
        widthSliderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(screenSizeInputView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        containerView.addSubview(heightSliderView)
        heightSliderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(widthSliderView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
    }
    
    func setData(size: J2MESize) {
        updateSize(width: size.width, height: size.height, callBlock: false)
    }
    
    private func updateSize(width: Int, height: Int, callBlock: Bool = true) {
        widthTextField.text = "\(width)"
        heightTextField.text = "\(height)"
        widthSliderView.value = Float(width)
        heightSliderView.value = Float(height)
        currentSize = J2MESize(width: width, height: height)
        if callBlock {
            didSetScreenSize?(currentSize)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class J2MESettingView: BaseView {
    
    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur()
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: J2MERotationSwitchCell.self)
        view.register(cellWithClass: J2MEScreenSizeCell.self)
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
            if PlayViewController.isGaming {
                var isChange: Bool = false
                if game.j2meScreenRotation != self.initScreenRotation {
                    isChange = true
                }
                if !isChange {
                    let currentSize = game.j2meScreenSize
                    if currentSize.cgSize != initScreenSize.cgSize {
                        isChange = true
                    }
                }
                if isChange {
                    UIView.makeAlert(title: R.string.localizable.headsUp(),
                                     detail: R.string.localizable.j2MEScreenChange(),
                                     cancelTitle: R.string.localizable.later(),
                                     confirmTitle: R.string.localizable.resetImmediately(), cancelAction: {
                        self.didTapClose?()
                    },confirmAction: {
                        NotificationCenter.default.post(name: Constants.NotificationName.ResetImmediately, object: nil)
                    })
                } else {
                    self.didTapClose?()
                }
            } else {
                self.didTapClose?()
            }
        }
        return view
    }()
    
    ///点击关闭按钮回调
    var didTapClose: (()->Void)? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
        Task { @MainActor in
            IQKeyboardManager.shared.isEnabled = false
        }
    }
    
    var game: Game
    private var initScreenRotation: Bool
    private var initScreenSize: J2MESize
    
    init(game: Game) {
        self.game = game
        self.initScreenRotation = game.j2meScreenRotation
        self.initScreenSize = game.j2meScreenSize
        super.init(frame: .zero)
        Log.debug("\(String(describing: Self.self)) init")
        backgroundColor = Constants.Color.Background
        
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.keyboardDistance = Constants.Size.ContentSpaceHuge
        
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

        let icon = UIImageView(image: R.image.customJava()!.applySymbolConfig(size: 30))
        icon.contentMode = .scaleAspectFit
        navigationBlurView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = R.string.localizable.j2MESettings()
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            let itemHeight: CGFloat
            if sectionIndex == 0 {
                itemHeight = Constants.Size.ItemHeightMax
            } else {
                itemHeight = 252
            }

            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemHeight)), subitems: [item])
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
            
            if sectionIndex != 0 {
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .estimated(44)),
                                                                             elementKind: UICollectionView.elementKindSectionFooter,
                                                                             alignment: .bottom)
                section.boundarySupplementaryItems.append(footerItem)
            }
            
            return section
        }
        return layout
    }
}

extension J2MESettingView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: J2MERotationSwitchCell.self, for: indexPath)
            cell.enableSwitchButton.setOn(game.j2meScreenRotation, animated: false)
            cell.enableSwitchButton.onChange { [weak self] value in
                guard let self else { return }
                self.game.updateExtra(key: ExtraKey.j2meScreenRotate.rawValue, value: value)
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: J2MEScreenSizeCell.self, for: indexPath)
            cell.setData(size: game.j2meScreenSize)
            cell.didSetScreenSize = { [weak self] size in
                guard let self else { return }
                self.game.updateExtra(key: ExtraKey.j2meScreenSize.rawValue, value: size.stringValue)
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorHaderReusableView.self, for: indexPath)
            header.titleLabel.text = indexPath.section == 0 ? R.string.localizable.rotateScreen() : R.string.localizable.screenSize()
            return header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorDetailFooterReusableView.self, for: indexPath)
            footer.titleLabel.text = R.string.localizable.j2MESettingsTips()
            return footer
        }
    }
}

extension J2MESettingView: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        collectionView.endEditing(true)
    }
}

extension J2MESettingView {
    static var isShow: Bool {
        Sheet.find(identifier: String(describing: J2MESettingView.self)).count > 0 ? true : false
    }
    
    static func show(game: Game, hideCompletion: (()->Void)? = nil) {
        Sheet.lazyPush(identifier: String(describing: J2MESettingView.self)) { sheet in
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
            
            let j2MESettingView = J2MESettingView(game: game)
            j2MESettingView.didTapClose = { [weak sheet] in
                sheet?.pop()
            }
            containerView.addSubview(j2MESettingView)
            j2MESettingView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            sheet.set(customView: view).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
}
