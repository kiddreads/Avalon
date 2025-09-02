//
//  ImportViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/29.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import SideMenu

class ImportViewController: BaseViewController {
    private var cornerMaskViewForiPad: TransparentHoleView = {
        let view = TransparentHoleView()
        return view
    }()
    
    private lazy var importServiceListView: ImportServiceListView = {
        let view = ImportServiceListView()
        view.addServiceButton.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.showSideMenu()
        }
        return view
    }()
    
    private lazy var addImportServiceView: AddImportServiceView = {
        let view = AddImportServiceView()
        view.requireToHideSideMenu = { [weak self] in
            guard let self = self else { return }
            self.hideSideMenu()
        }
        return view
    }()
    
    private weak var sideMenu: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
    }
    
    private func setupViews() {
        if UIDevice.isPhone {
            view.addSubview(importServiceListView)
            importServiceListView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            view.backgroundColor = .black
            importServiceListView.backgroundColor = Constants.Color.Background
            importServiceListView.addServiceButton.isHidden = true
            view.addSubview(importServiceListView)
            importServiceListView.snp.makeConstraints { make in
                make.top.bottom.trailing.equalToSuperview()
                make.width.equalToSuperview().offset(-Constants.Size.SideMenuWidth*1.15)
            }
            
            view.addSubview(addImportServiceView)
            addImportServiceView.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.trailing.equalTo(importServiceListView.snp.leading)
            }
            
            view.addSubview(cornerMaskViewForiPad)
            cornerMaskViewForiPad.snp.makeConstraints { make in
                make.edges.equalTo(importServiceListView)
            }
        }
    }
    
    override func handleScreenPanGesture(edges: UIRectEdge) {
        if UIDevice.isPhone || (UIDevice.isPad && !UIDevice.isLandscape) {
            if edges == .left {
                showSideMenu()
            }
        }
    }
    
    private func showSideMenu() {
        UIDevice.generateHaptic()
        let vc = AddImportServiceViewController(addImportServiceView: addImportServiceView)
        let menu = SideMenuNavigationController(rootViewController: vc)
        menu.navigationBar.isHidden = true
        menu.presentDuration = Constants.Numbers.LongAnimationDuration
        menu.dismissDuration = Constants.Numbers.LongAnimationDuration
        menu.leftSide = !Locale.isRTLLanguage
        menu.menuWidth = Constants.Size.SideMenuWidth
        menu.presentationStyle = SideMenuShowStyle()
        topViewController()?.present(menu, animated: true)
        sideMenu = menu
    }
    
    private func hideSideMenu() {
        sideMenu?.dismiss(animated: true)
    }
}
