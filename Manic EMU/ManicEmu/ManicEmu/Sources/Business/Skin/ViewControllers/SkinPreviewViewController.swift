//
//  SkinPreviewViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ManicEmuCore
import AVFoundation

class SkinPreviewViewController: BaseViewController {
    
    private let skin: ControllerSkin
    private let traits: ControllerSkin.Traits
    
    private lazy var controlView: ControllerView = {
        let view = ControllerView()
        view.customControllerSkinTraits = traits
        view.controllerSkin = skin
        view.addReceiver(self)
        return view
    }()

    init(skin: ControllerSkin, traits: ControllerSkin.Traits) {
        self.skin = skin
        self.traits = traits
        super.init(fullScreen: true)
        
        view.addSubview(controlView)
        
        var needToRotate = false
        if traits.orientation == .portrait && (UIDevice.currentOrientation == .landscapeLeft || UIDevice.currentOrientation == .landscapeRight) {
            needToRotate = true
        } else if traits.orientation == .landscape && (UIDevice.currentOrientation == .portrait || UIDevice.currentOrientation == .portraitUpsideDown) {
            needToRotate = true
        }
        
        if needToRotate {
            controlView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                if let aspectRatio = skin.aspectRatio(for: traits) {
                    let frame = AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: CGSize(width: Constants.Size.WindowHeight, height: Constants.Size.WindowWidth)))
                    make.size.equalTo(frame.size)
                }
            }
            controlView.transform = .init(rotationAngle: .pi/2)
        } else {
            controlView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                if let aspectRatio = skin.aspectRatio(for: traits) {
                    let frame = AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: Constants.Size.WindowSize))
                    make.size.equalTo(frame.size)
                }
            }
        }
        
        view.addSubview(closeButton)
        closeButton.addTapGesture { [weak self] gesture in
            self?.dismiss(animated: true)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.Size.SafeAera.top == 0 ? 20 : Constants.Size.SafeAera.top)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
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

extension SkinPreviewViewController: ControllerReceiverProtocol {
    func gameController(_ gameController: any ManicEmuCore.GameController, didDeactivate input: any ManicEmuCore.Input) {
        
    }
    
    func gameController(_ gameController: any GameController, didActivate input: any Input, value: Double) {
        Log.debug("点击 input:\(input) value:\(value)")
#if DEBUG
        UIView.makeToast(message: "\(input.stringValue)", duration: 1)
#endif
    }
}
