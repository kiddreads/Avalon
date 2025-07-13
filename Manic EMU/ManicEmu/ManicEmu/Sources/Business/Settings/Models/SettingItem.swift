//
//  SettingItem.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

struct SettingItem {
    
    enum ItemType: String {
        case theme, leftHand, quickGame, airPlay, iCloud, fullScreenWhenConnectController, AppIcon, widget, FAQ, feedback, shareApp, qq, telegram, discord, clearCache, language, userAgreement, privacyPolicy, autoSaveState, bios, respectSilentMode
    }
    
    var type: ItemType
    var isOn: Bool? = false
    var arrowDetail: String? = nil
    
    var backgroundColor: UIColor {
        switch type {
        case .theme, .leftHand, .feedback, .fullScreenWhenConnectController:
            Constants.Color.Magenta
        case .quickGame, .shareApp:
            Constants.Color.Green
        case .airPlay, .FAQ, .clearCache, .autoSaveState:
            Constants.Color.Blue
        case .iCloud, .language, .bios:
            Constants.Color.Indigo
        case .AppIcon, .userAgreement, .respectSilentMode:
            Constants.Color.Purple
        case .widget, .privacyPolicy:
            Constants.Color.Yellow
        case .qq, .telegram, .discord:
                .clear
        }
    }
    
    var icon: UIImage {
        switch type {
        case .theme:
            UIImage(symbol: .paintpaletteFill, font: Constants.Font.body(size: .s, weight: .medium))
        case .leftHand:
            UIImage(symbol: .handPointLeftFill, font: Constants.Font.body(size: .s, weight: .medium))
        case .quickGame:
            UIImage(symbol: .hareFill, font: Constants.Font.caption(size: .m, weight: .medium))
        case .airPlay:
            UIImage(symbol: .airplayvideo, font: Constants.Font.body(size: .s, weight: .medium))
        case .iCloud:
            if #available(iOS 17.0, *) {
                UIImage(symbol: .arrowTriangle2CirclepathIcloudFill, font: Constants.Font.body(size: .s, weight: .medium))
            } else {
                UIImage(symbol: .cloudFill, font: Constants.Font.body(size: .s, weight: .medium))
            }
        case .AppIcon:
            UIImage(symbol: .appFill, font: Constants.Font.body(size: .s, weight: .medium)).rotated(by: 15/180) ?? UIImage(symbol: .appFill)
        case .widget:
            R.image.customWidgetSmall()!.applySymbolConfig(font: Constants.Font.body(size: .s, weight: .medium))
        case .FAQ:
            UIImage(symbol: .questionmarkAppFill, font: Constants.Font.body(size: .s, weight: .medium))
        case .feedback:
            UIImage(symbol: .questionmarkAppFill, font: Constants.Font.body(size: .s, weight: .medium))
        case .shareApp:
            UIImage(symbol: .squareAndArrowUpFill, font: Constants.Font.body(size: .s, weight: .medium))
        case .qq:
            R.image.settings_qq()!
        case .telegram:
            R.image.settings_telegram()!
        case .discord:
            R.image.settings_discord()!
        case .clearCache:
            UIImage(symbol: .paintbrushFill, font: Constants.Font.body(size: .s, weight: .medium))
        case .language:
            UIImage(symbol: .globe, font: Constants.Font.body(size: .s, weight: .medium))
        case .userAgreement:
            UIImage(symbol: .docTextFill, font: Constants.Font.body(size: .s, weight: .medium))
        case .privacyPolicy:
            UIImage(symbol: .shieldLefthalfFilled, font: Constants.Font.body(size: .s, weight: .medium))
        case .fullScreenWhenConnectController:
            R.image.customArrowDownLeftAndArrowUpRight()!.applySymbolConfig(font: Constants.Font.body(size: .s, weight: .medium))
        case .autoSaveState:
            UIImage(symbol: .arrowDownDoc, font: Constants.Font.body(size: .s, weight: .medium))
        case .bios:
            UIImage(symbol: .cpu, font: Constants.Font.body(size: .s, weight: .medium))
        case .respectSilentMode:
            UIImage(symbol: .bell, font: Constants.Font.body(size: .s, weight: .medium))
        }
    }
    
    var title: String {
        switch type {
        case .theme:
            R.string.localizable.themeSettingTitle()
        case .leftHand:
            R.string.localizable.quickGameTitle()
        case .quickGame:
            R.string.localizable.quickGameTitle()
        case .airPlay:
            R.string.localizable.airPlayTitle()
        case .iCloud:
            R.string.localizable.iCloudTitle()
        case .AppIcon:
            R.string.localizable.appIconTitle()
        case .widget:
            R.string.localizable.widgetTitle()
        case .FAQ:
            R.string.localizable.qaTitle()
        case .feedback:
            R.string.localizable.feedbackTitle()
        case .shareApp:
            R.string.localizable.shareAppTitle()
        case .qq:
            R.string.localizable.joinQQTitle()
        case .telegram:
            R.string.localizable.joinTelegramTitle()
        case .discord:
            R.string.localizable.joinDiscordTitle()
        case .clearCache:
            R.string.localizable.clearCacheTitle()
        case .language:
            R.string.localizable.languageTitle()
        case .userAgreement:
            R.string.localizable.userAgreementTitle()
        case .privacyPolicy:
            R.string.localizable.privacyPolicyTitle()
        case .fullScreenWhenConnectController:
            R.string.localizable.fullScreenWhenConnectControllerTitle()
        case .autoSaveState:
            R.string.localizable.autoSaveStateTitle()
        case .bios:
            "BIOS"
        case .respectSilentMode:
            R.string.localizable.respectSilentMode()
        }
    }
    
    var detail: String? {
        if type == .leftHand {
            return R.string.localizable.leftHandDetail()
        } else if type == .quickGame {
            return R.string.localizable.quickGameDetail()
        } else if type == .airPlay {
            return R.string.localizable.airPlayDetail()
        } else if type == .iCloud {
            return R.string.localizable.iCloudDetail()
        } else if type == .fullScreenWhenConnectController {
            return R.string.localizable.fullScreenWhenConnectControllerDetail()
        } else if type == .theme {
            return R.string.localizable.themeSettingDetail()
        } else if type == .bios {
            return R.string.localizable.biosDesc()
        } else if type == .respectSilentMode {
            return R.string.localizable.respectSilentModeDesc()
        }
        return nil
    }
}
