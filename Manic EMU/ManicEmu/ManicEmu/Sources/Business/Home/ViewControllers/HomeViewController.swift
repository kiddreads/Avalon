//
//  HomeViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//

import UIKit
import SideMenu
import DNSPageView
import ColorfulX
import ManicEmuCore
import UniformTypeIdentifiers
import BlurUIKit

class HomeViewController: BaseViewController {
    private lazy var gamesViewController: GamesViewController = {
        let controller = GamesViewController()
        controller.setHomeTabBar = { [weak self] show in
            UIView.springAnimate(enable: show) { 
                self?.homeTabBar.alpha = show ? 1 : 0
                self?.homeTabBarBlurView.isHidden = !show
            }
        }
        return controller
    }()
    
    private var importViewController: ImportViewController = {
        let controller = ImportViewController()
        return controller
    }()
    
    private var settingsViewController: SettingsViewController = {
        let controller = SettingsViewController()
        return controller
    }()
    
    private lazy var childControllers: [BaseViewController] = {
        if Locale.isRTLLanguage {
            [settingsViewController, importViewController, gamesViewController]
        } else {
            [gamesViewController, importViewController, settingsViewController]
        }
        
    }()
    
    private lazy var pageViewManager: PageViewManager = {
        let style = PageStyle()
        style.contentViewBackgroundColor = UIDevice.isPad ? .black : Constants.Color.Background
        let manager = PageViewManager(style: style, titles: HomeTabBar.BarSelection.allCases.map { String($0.rawValue) }, childViewControllers: childControllers)
        childControllers.forEach {
            addChild($0)
            $0.didMove(toParent: self)
        }
        return manager
    }()
    
    private lazy var homeTabBar: HomeTabBar = {
        let view = HomeTabBar()
        view.selectionChange = { [weak self] selection in
            var selection = selection
            if Locale.isRTLLanguage {
                if selection == .games {
                    selection = .settings
                } else if selection == .settings {
                    selection = .games
                }
            }
            self?.pageViewManager.setCurrentPage(selection.rawValue)
        }
        return view
    }()
    
    private var homeTabBarBlurView: UIView = {
        let view = BlurUIKit.VariableBlurView()
        view.direction = .up
        view.maximumBlurRadius = 15
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.5, darkModeAlpha: 0.6)
        view.dimmingTintColor = Constants.Color.Background
        return view
    }()
    
    private var homeSelectionChangeNotification: Any? = nil
    
    private(set) var currentSelection: HomeTabBar.BarSelection {
        set {
            self.homeTabBar.currentSelection = newValue
            switch newValue {
            case .games:
                Log.debug("切换到游戏")
            case .imports:
                Log.debug("切换到导入")
            case .settings:
                Log.debug("切换到设置")
            }
        }
        get {
            self.homeTabBar.currentSelection
        }
    }
    
    deinit {
        if let homeSelectionChangeNotification = homeSelectionChangeNotification {
            NotificationCenter.default.removeObserver(homeSelectionChangeNotification)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        self.setupViews()
        self.setupDatas()
        
        homeSelectionChangeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.HomeSelectionChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let selection = notification.object as? HomeTabBar.BarSelection {
                if self.presentedViewController == nil {
                    if self.currentSelection != selection {
                        self.currentSelection = selection
                    }
                }
            }
        }
    }
    
    private func setupViews() {
        view.addScreenEdgePanGesture(edges: .left, handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self = self else { return }
                self.childControllers[self.pageViewManager.currentIndex].handleScreenPanGesture(edges: .left)
            }
        }).delegate = self
        
        view.addScreenEdgePanGesture(edges: .right, handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self = self else { return }
                self.childControllers[self.pageViewManager.currentIndex].handleScreenPanGesture(edges: .right)
            }
        }).delegate = self
        
        view.addSubview(pageViewManager.contentView)
        pageViewManager.contentView.delegate = self
        pageViewManager.contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if Locale.isRTLLanguage {
            DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self] in
                self?.pageViewManager.setCurrentPage(HomeTabBar.BarSelection.settings.rawValue)
            }
        }
        
        view.addSubview(homeTabBarBlurView)
        view.addSubview(homeTabBar)
        homeTabBarBlurView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(homeTabBar.snp.centerY)
        }
        
        homeTabBar.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.HomeTabBarSize)
            make.centerX.equalTo(self.view)
            let safeAeraBottom = Constants.Size.SafeAera.bottom
            make.bottom.equalTo(safeAeraBottom > 0 ? -safeAeraBottom: -Constants.Size.ContentSpaceMax)
        }
    }
    
    private func setupDatas() {

    }
}

extension HomeViewController: UIGestureRecognizerDelegate {
    // 让 UICollectionView 的手势在 EdgePan 失败后才识别
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIScreenEdgePanGestureRecognizer,
           let scrollView = otherGestureRecognizer.view as? UIScrollView,
           otherGestureRecognizer == scrollView.panGestureRecognizer {
            return true // 先执行 EdgePan，失败后才允许 UICollectionView 滚动
        }
        return false
    }
}

extension HomeViewController: PageContentViewDelegate {
    func contentView(_ contentView: DNSPageView.PageContentView, didEndScrollAt index: Int) {
        var index = index
        if Locale.isRTLLanguage {
            if index == HomeTabBar.BarSelection.games.rawValue {
                index = HomeTabBar.BarSelection.settings.rawValue
            } else if index == HomeTabBar.BarSelection.settings.rawValue {
                index = HomeTabBar.BarSelection.games.rawValue
            }
        }
        if let selection = HomeTabBar.BarSelection(rawValue: index) {
            homeTabBar.currentSelection = selection
        }
    }
    
    func contentView(_ contentView: DNSPageView.PageContentView, scrollingWith sourceIndex: Int, targetIndex: Int, progress: CGFloat) {
        
    }
}
