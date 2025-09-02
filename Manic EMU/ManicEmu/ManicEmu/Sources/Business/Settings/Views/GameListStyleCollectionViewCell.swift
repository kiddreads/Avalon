//
//  GameListStyleCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import BetterSegmentedControl
import TKSwitcherCollection

class GameListStyleCollectionViewCell: UICollectionViewCell {
    
    lazy var gamesPerRowSegmentView: BetterSegmentedControl = {
        let titles = ["2", "3", "4", "5"]
        let segments = LabelSegment.segments(withTitles: titles,
                                             normalFont: Constants.Font.body(),
                                             normalTextColor: Constants.Color.LabelSecondary,
                                            selectedTextColor: Constants.Color.LabelPrimary)
        let options: [BetterSegmentedControl.Option] = [
            .backgroundColor(Constants.Color.BackgroundPrimary),
            .indicatorViewInset(5),
            .indicatorViewBackgroundColor(Constants.Color.BackgroundSecondary),
            .cornerRadius(16)
        ]
        let view = BetterSegmentedControl(frame: .zero,
                                          segments: segments,
                                          options: options)
        return view
    }()
    
    private var gamesPerRowLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelPrimary
        label.text = R.string.localizable.gamesPerRowTitle()
        return label
    }()
    
    lazy var groupTitleStyleSegmentView: BetterSegmentedControl = {
        let titles = [R.string.localizable.groupTitleStyelAbbr(),
                      R.string.localizable.groupTitleStyelFull(),
                      R.string.localizable.groupTitleStyelBrand()]
        let segments = LabelSegment.segments(withTitles: titles,
                                             normalFont: Constants.Font.body(),
                                             normalTextColor: Constants.Color.LabelSecondary,
                                            selectedTextColor: Constants.Color.LabelPrimary)
        let options: [BetterSegmentedControl.Option] = [
            .backgroundColor(Constants.Color.BackgroundPrimary),
            .indicatorViewInset(5),
            .indicatorViewBackgroundColor(Constants.Color.BackgroundSecondary),
            .cornerRadius(16)
        ]
        let view = BetterSegmentedControl(frame: .zero,
                                          segments: segments,
                                          options: options)
        return view
    }()
    
    private var groupTitleStyleLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelPrimary
        label.text = R.string.localizable.groupTitleStyelDesc()
        return label
    }()
    
    private var hideScrollIndicatorIconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.layerCornerRadius = 6
        view.image = UIImage(symbol: .calendarDayTimelineTrailing, font: Constants.Font.body(size: .s, weight: .medium))
        return view
    }()
    
    private var  hideScrollIndicatorButton: TKSimpleSwitch = {
        let view = TKSimpleSwitch()
        view.onColor = Constants.Color.Main
        view.offColor = Constants.Color.BackgroundTertiary
        view.lineColor = .clear
        view.lineSize = 0
        return view
    }()
    
    private var hideGroupTitleIconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.layerCornerRadius = 6
        view.image = UIImage(symbol: .listBullet, font: Constants.Font.body(size: .s, weight: .medium))
        return view
    }()
    
    private var hideGroupTitleSwitchButton: TKSimpleSwitch = {
        let view = TKSimpleSwitch()
        view.onColor = Constants.Color.Main
        view.offColor = Constants.Color.BackgroundTertiary
        view.lineColor = .clear
        view.lineSize = 0
        return view
    }()
    
    private var mainColorChangeNotification: Any? = nil
    
    deinit {
        if let mainColorChangeNotification = mainColorChangeNotification {
            NotificationCenter.default.removeObserver(mainColorChangeNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layerCornerRadius = Constants.Size.CornerRadiusMax
        backgroundColor = Constants.Color.BackgroundSecondary
        
        let theme = Theme.defalut
        //游戏行数
        addSubview(gamesPerRowLabel)
        gamesPerRowLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.top.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
        }
        
        gamesPerRowSegmentView.setIndex(theme.gamesPerRow-2)
        addSubview(gamesPerRowSegmentView)
        gamesPerRowSegmentView.snp.makeConstraints { make in
            make.top.equalTo(gamesPerRowLabel.snp.bottom).offset(Constants.Size.ContentSpaceMid)
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        gamesPerRowSegmentView.on(.valueChanged) { sender, forEvent in
            guard let index = (sender as? BetterSegmentedControl)?.index else { return }
            UIDevice.generateHaptic()
            Theme.change { realm in
                theme.gamesPerRow = index + 2
            }
        }
        
        //隐藏滚动条
        let hideScrollIndicatorContainer = UIView()
        hideScrollIndicatorContainer.backgroundColor = Constants.Color.BackgroundPrimary
        hideScrollIndicatorContainer.layerCornerRadius = Constants.Size.CornerRadiusMid
        addSubview(hideScrollIndicatorContainer)
        hideScrollIndicatorContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(gamesPerRowSegmentView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        hideScrollIndicatorContainer.addSubview(hideScrollIndicatorIconView)
        hideScrollIndicatorIconView.backgroundColor = Constants.Color.Main
        hideScrollIndicatorIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMin)
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.centerY.equalToSuperview()
        }
        
        let hideScrollIndicatorTitleLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 3
            let matt = NSMutableAttributedString(string: R.string.localizable.gamesHideScrollIndicator(), attributes: [.font: Constants.Font.body(size: .l, weight: .semibold), .foregroundColor: Constants.Color.LabelPrimary])
            view.attributedText = matt
            return view
        }()
        hideScrollIndicatorContainer.addSubview(hideScrollIndicatorTitleLabel)
        hideScrollIndicatorTitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(hideScrollIndicatorIconView)
            make.leading.equalTo(hideScrollIndicatorIconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().offset(-46-Constants.Size.ContentSpaceMid)
        }
        
        hideScrollIndicatorContainer.addSubview(hideScrollIndicatorButton)
        hideScrollIndicatorButton.setOn(theme.hideIndicator, animate: false)
        hideScrollIndicatorButton.snp.makeConstraints { make in
            make.centerY.equalTo(hideScrollIndicatorIconView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMin)
            make.size.equalTo(CGSize(width: 46, height: 28))
        }
        hideScrollIndicatorButton.onChange { value in
            Theme.change { realm in
                theme.hideIndicator = value
            }
        }
        
        //分组标题样式
        addSubview(groupTitleStyleLabel)
        groupTitleStyleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.top.equalTo(hideScrollIndicatorContainer.snp.bottom).offset(Constants.Size.ContentSpaceMax)
        }
        
        groupTitleStyleSegmentView.setIndex(theme.groupTitleStyle.rawValue)
        addSubview(groupTitleStyleSegmentView)
        groupTitleStyleSegmentView.snp.makeConstraints { make in
            make.top.equalTo(groupTitleStyleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMid)
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        groupTitleStyleSegmentView.on(.valueChanged) { sender, forEvent in
            guard let index = (sender as? BetterSegmentedControl)?.index else { return }
            UIDevice.generateHaptic()
            if let style = GroupTitleStyle(rawValue: index) {
                Theme.change { realm in
                    theme.groupTitleStyle = style
                }
            }
        }
        
        //隐藏分组标题
        let hideGroupTitleContainer = UIView()
        hideGroupTitleContainer.backgroundColor = Constants.Color.BackgroundPrimary
        hideGroupTitleContainer.layerCornerRadius = Constants.Size.CornerRadiusMid
        addSubview(hideGroupTitleContainer)
        hideGroupTitleContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(groupTitleStyleSegmentView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        hideGroupTitleContainer.addSubview(hideGroupTitleIconView)
        hideGroupTitleIconView.backgroundColor = Constants.Color.Main
        hideGroupTitleIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMin)
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.centerY.equalToSuperview()
        }
        
        let hideGroupTitleLabel: UILabel = {
            let view = UILabel()
            view.font = Constants.Font.body(size: .l, weight: .semibold)
            view.textColor = Constants.Color.LabelPrimary
            view.text = R.string.localizable.hideGroupTitleDesc()
            return view
        }()
        hideGroupTitleContainer.addSubview(hideGroupTitleLabel)
        hideGroupTitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(hideGroupTitleIconView)
            make.leading.equalTo(hideGroupTitleIconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().offset(-46-Constants.Size.ContentSpaceMid)
        }
        
        hideGroupTitleContainer.addSubview(hideGroupTitleSwitchButton)
        hideGroupTitleSwitchButton.setOn(theme.hideGroupTitle, animate: false)
        hideGroupTitleSwitchButton.snp.makeConstraints { make in
            make.centerY.equalTo(hideGroupTitleIconView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMin)
            make.size.equalTo(CGSize(width: 46, height: 28))
        }
        hideGroupTitleSwitchButton.onChange { value in
            Theme.change { realm in
                theme.hideGroupTitle = value
            }
        }
        
        mainColorChangeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.MainColorChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.hideScrollIndicatorButton.onColor = Constants.Color.Main
            self.hideGroupTitleSwitchButton.onColor = Constants.Color.Main
            self.hideScrollIndicatorButton.reload()
            self.hideGroupTitleSwitchButton.reload()
            self.hideScrollIndicatorIconView.backgroundColor = Constants.Color.Main
            self.hideGroupTitleIconView.backgroundColor = Constants.Color.Main
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
