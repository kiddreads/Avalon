//
//  ControllerMappingViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ManicEmuCore

class ControllerMappingViewController: BaseViewController {
    private var controllerMappingView: ControllerMappingView
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init() is unavailable")
    }
    
    init(gameType: GameType = .ps1, controller: GameController) {
        self.controllerMappingView = ControllerMappingView(gameType: gameType, controller: controller)
        super.init(fullScreen: true)
        self.controllerMappingView.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(controllerMappingView)
        controllerMappingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch UIDevice.currentOrientation {
        case .portrait:
            AppDelegate.orientation = .portrait
        case .portraitUpsideDown:
            AppDelegate.orientation = .portraitUpsideDown
        case .landscapeLeft:
            AppDelegate.orientation = .landscapeLeft
        case .landscapeRight:
            AppDelegate.orientation = .landscapeRight
        default: break
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.orientation = Constants.Config.DefaultOrientation
    }
}
