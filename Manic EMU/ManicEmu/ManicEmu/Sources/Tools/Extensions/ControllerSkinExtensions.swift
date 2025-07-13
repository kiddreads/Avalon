//
//  ControllerSkinExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore
import AVFoundation

extension ControllerSkin {
    func getFrames(traits: ControllerSkin.Traits = ControllerSkin.Traits.defaults(for: UIWindow.applicationWindow ?? UIWindow(frame: .init(origin: .zero, size: Constants.Size.WindowSize)))) -> (skinFrame: CGRect, mainGameViewFrame: CGRect, touchGameViewFrame: CGRect?)? {
        if let screens = self.screens(for: traits), let aspectRatio = self.aspectRatio(for: traits) {
            let skinFrame = AVMakeRect(aspectRatio: aspectRatio, insideRect: UIScreen.main.bounds).rounded()
            var mainGameViewFrame: CGRect = .zero
            var touchGameViewFrame: CGRect? = nil
            for screen in screens {
                if let outputFrame = screen.outputFrame {
                    if screen.isTouchScreen {
                        touchGameViewFrame = outputFrame.applying(.init(scaleX: skinFrame.width, y: skinFrame.height)).rounded()
                    } else {
                        mainGameViewFrame = outputFrame.applying(.init(scaleX: skinFrame.width, y: skinFrame.height)).rounded()
                    }
                }
            }
            return (skinFrame, mainGameViewFrame, touchGameViewFrame)
        }
        return nil
    }
}
