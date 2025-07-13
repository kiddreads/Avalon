//
//  GameInfoDetailReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit
import BetterSegmentedControl
import RealmSwift
import UniformTypeIdentifiers

class GameInfoDetailReusableView: UICollectionReusableView {
    var backgroundBlurView: UIView = {
        let view = UIView()
        view.makeBlur()
        view.alpha = 0
        return view
    }()
    
    lazy var titleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = Constants.Color.LabelPrimary
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
            if let game = self.game, let text = textField?.text?.trimmed {
                if text.isEmpty {
                    textField?.text = game.aliasName ?? game.name
                    UIView.makeToast(message: R.string.localizable.readyEditTitleFailed())
                } else if text != game.aliasName {
                    Game.change { realm in
                        game.aliasName = text
                    }
                }
            }
        }
        textField.onChange { [weak textField] text in
            if text.count > Constants.Size.GameNameMaxCount {
                if let markRange = textField?.markedTextRange, let _ = textField?.position(from: markRange.start, offset: 0) { } else {
                    textField?.text = String(text.prefix(Constants.Size.GameNameMaxCount))
                }
            }
        }
        return textField
    }()
    
    private lazy var editTitleButton: SymbolButton = {
        let view = SymbolButton(image: R.image.customPencilLine()?.applySymbolConfig(size: Constants.Size.IconSizeMin.height))
        view.backgroundColor = .clear
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if !self.titleTextField.isFirstResponder {
                self.titleTextField.becomeFirstResponder()
            }
        }
        return view
    }()
    
    private var subtitleIcon: UIImageView = {
        let view = UIImageView()
        view.image = .symbolImage(.starCircleFill)
        return view
    }()
    
    private var subtitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelSecondary
        view.font = Constants.Font.body()
        return view
    }()
    
    private var functionButtonContainerView: UIScrollView = {
        let view = UIScrollView()
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        if Locale.isRTLLanguage {
            view.semanticContentAttribute = .forceLeftToRight
        }
        return view
    }()

    private lazy var skinButton: SymbolButton = {
        let view = SymbolButton(symbol: .tshirt, title: R.string.localizable.gamesSpecifySkin())
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                topViewController()?.present(SkinSettingsViewController(game: game), animated: true)
            }
        }
        return view
    }()
    
    private lazy var cheatCodeButton: SymbolButton = {
        let view = SymbolButton(image: R.image.customAppleTerminal()?.applySymbolConfig(), title: R.string.localizable.gamesCheatCode())
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                topViewController()?.present(CheatCodeViewController(game: game), animated: true)
            }
        }
        return view
    }()
    
    private lazy var threeDSModecontextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.threeDSModePerformance()) { [weak self] _ in
            guard let self = self else { return }
            self.threeDSModeButton.titleLabel.text = R.string.localizable.threeDSModePerformance()
            Settings.change { realm in
                Settings.defalut.threeDSMode = .performance
            }
        }))
        actions.append(UIAction(title: R.string.localizable.threeDSModeCompatibility()) { [weak self] _ in
            guard let self = self else { return }
            self.threeDSModeButton.titleLabel.text = R.string.localizable.threeDSModeCompatibility()
            Settings.change { realm in
                Settings.defalut.threeDSMode = .compatibility
            }
        })
        actions.append((UIAction(title: R.string.localizable.threeDSModeQuality()) { [weak self] _ in
            guard let self = self else { return }
            self.threeDSModeButton.titleLabel.text = R.string.localizable.threeDSModeQuality()
            Settings.change { realm in
                Settings.defalut.threeDSMode = .quality
            }
        }))
        let view = ContextMenuButton(image: nil, menu: UIMenu(children: actions))
        return view
    }()
    
    private lazy var threeDSModeButton: SymbolButton = {
        let title: String
        switch Settings.defalut.threeDSMode {
        case .performance:
            title = R.string.localizable.threeDSModePerformance()
        case .compatibility:
            title = R.string.localizable.threeDSModeCompatibility()
        case .quality:
            title = R.string.localizable.threeDSModeQuality()
        }
        let view = SymbolButton(symbol: .gearshape2, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.threeDSModecontextMenuButton.triggerTapGesture()
        }
        return view
    }()
    
    private lazy var jitContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.on()) { [weak self] _ in
            guard let self = self else { return }
            self.jitButton.titleLabel.text = "JIT \(R.string.localizable.on())"
            if let game {
                Game.change { _ in
                    game.jit = true
                }
            }
        }))
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            self.jitButton.titleLabel.text = "JIT \(R.string.localizable.off())"
            if let game {
                Game.change { _ in
                    game.jit = false
                }
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.jitMenuDesc(), children: actions))
        return view
    }()
    
    private lazy var jitButton: SymbolButton = {
        let title: String
        let jitAvailable = LibretroCore.jitAvailable()
        if jitAvailable {
            if game?.jit ?? false {
                title = "JIT \(R.string.localizable.on())"
            } else {
                title = "JIT \(R.string.localizable.off())"
            }
        } else {
            title = "JIT \(R.string.localizable.off())"
        }
        
        let view = SymbolButton(symbol: .bolt, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if jitAvailable {
                self.jitContextMenuButton.triggerTapGesture()
            } else {
                UIView.makeToast(message: R.string.localizable.jitNoSupportDesc())
            }
        }
        return view
    }()
    
    private lazy var shaderContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.on()) { [weak self] _ in
            guard let self = self else { return }
            self.shaderButton.titleLabel.text = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.on())"
            if let game {
                Game.change { _ in
                    game.accurateShaders = true
                }
            }
        }))
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            self.shaderButton.titleLabel.text = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.off())"
            if let game {
                Game.change { _ in
                    game.accurateShaders = false
                }
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.shaderModeDesc(), children: actions))
        return view
    }()
    
    private lazy var shaderButton: SymbolButton = {
        let title: String
        if game?.accurateShaders ?? false {
            title = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.on())"
        } else {
            title = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.off())"
        }
        let view = SymbolButton(image: R.image.customLightspectrumHorizontal()?.applySymbolConfig(color: Constants.Color.LabelPrimary), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.shaderContextMenuButton.triggerTapGesture()
        }
        return view
    }()
    
    private lazy var languageContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        var languages = [String]()
        if let game {
            if game.gameType == ._3ds {
                languages = Constants.Strings.ThreeDSConsoleLanguage
            } else if game.gameType == .psp {
                languages = Constants.Strings.PSPConsoleLanguage
            } else if game.gameType == .ss {
                languages = Constants.Strings.SaturnConsoleLanguage
            } else if game.gameType == .ds {
                languages = Constants.Strings.DSConsoleLanguage
            }
        }
        for (index, language) in languages.enumerated() {
            actions.append((UIAction(title: language) { [weak self] _ in
                guard let self = self else { return }
                self.languageButton.titleLabel.text = language
                if let game {
                    Game.change { _ in
                        game.region = index
                    }
                }
            }))
        }
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.consoleLanguageDesc(), children: actions))
        return view
    }()
    
    private lazy var languageButton: SymbolButton = {
        var title: String = ""
        if let game {
            var languages = [String]()
            if game.gameType == ._3ds {
                languages = Constants.Strings.ThreeDSConsoleLanguage
            } else if game.gameType == .psp {
                languages = Constants.Strings.PSPConsoleLanguage
            } else if game.gameType == .ss {
                languages = Constants.Strings.SaturnConsoleLanguage
            } else if game.gameType == .ds {
                languages = Constants.Strings.DSConsoleLanguage
            }
            if game.region < languages.count {
                title = languages[game.region]
            }
        }
        let view = SymbolButton(symbol: .characterBubble, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.languageContextMenuButton.triggerTapGesture()
        }
        return view
    }()
    
    private lazy var rightEyeRenderMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.disableTitle()) { [weak self] _ in
            guard let self = self else { return }
            self.rightEyeRenderButton.titleLabel.text = R.string.localizable.disableTitle() + R.string.localizable.renderRightEyeTitle()
            self.rightEyeRenderButton.imageView.image = .symbolImage(.eyeSlash)
            if let game {
                Game.change { _ in
                    game.renderRightEye = false
                }
            }
        }))
        actions.append(UIAction(title: R.string.localizable.enableTitle()) { [weak self] _ in
            guard let self = self else { return }
            self.rightEyeRenderButton.titleLabel.text = R.string.localizable.enableTitle() + R.string.localizable.renderRightEyeTitle()
            self.rightEyeRenderButton.imageView.image = .symbolImage(.eye)
            if let game {
                Game.change { _ in
                    game.renderRightEye = true
                }
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.renderRightEyeDesc(), children: actions))
        return view
    }()
    
    private lazy var rightEyeRenderButton: SymbolButton = {
        var title: String = R.string.localizable.renderRightEyeTitle()
        let enableRightEyeRender = game?.renderRightEye ?? false
        if enableRightEyeRender {
            title = R.string.localizable.enableTitle() + title
        } else {
            title = R.string.localizable.disableTitle() + title
        }
        let view = SymbolButton(symbol: enableRightEyeRender ? .eye : .eyeSlash, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.rightEyeRenderMenuButton.triggerTapGesture()
        }
        return view
    }()
    
    private lazy var threeDSAdvancedSettingButton: SymbolButton = {
        let view = SymbolButton(symbol: .gear, title: R.string.localizable.threeDSAdvanceSettingTitle(), horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { gesture in
            topViewController()?.present(ThreeDSAdvancedSettingViewController(), animated: true)
        }
        return view
    }()
    
    private lazy var transferPakContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: R.string.localizable.transferPakFromLibrary()) { [weak self] _ in
            guard let self = self else { return }
            //从游戏库导入
            let realm = Database.realm
            let objects = realm.objects(Game.self).where({ !$0.isDeleted && ($0.gameType == .gbc || $0.gameType == .gb) }).filter({ $0.isSaveExtsts })
            var games = [Game]()
            games.append(contentsOf: objects)
            if games.count > 0 {
                GameSaveMatchGameView.show(showGames: games, title: "Transfer Pak", detail: R.string.localizable.transferPakFromLibraryDesc(), cancelTitle: R.string.localizable.cancelTitle()) { [weak self] selectedGame in
                    guard let self = self else { return }
                    if let game = self.game, let selectedGame, selectedGame.isRomExtsts, selectedGame.isSaveExtsts {
                        try? FileManager.safeCopyItem(at: selectedGame.romUrl, to: URL(fileURLWithPath: game.romUrl.path + ".gb"), shouldReplace: true)
                        try? FileManager.safeCopyItem(at: selectedGame.gameSaveUrl, to: URL(fileURLWithPath: game.romUrl.path + ".sav"), shouldReplace: true)
                        self.transferPakButton.titleLabel.text = "Transfer Pak\n\(R.string.localizable.transferPakOn())"
                        UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                    }
                }
            } else {
                UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            }
        })
        actions.append(UIAction(title: R.string.localizable.transferPakFromFiles()) { [weak self] _ in
            guard let self = self else { return }
            //从文件导入
            if let gb = UTType(filenameExtension: "gb"), let gbc = UTType(filenameExtension: "gbc"), let sav = UTType(filenameExtension: "sav") {
                FilesImporter.shared.presentImportController(supportedTypes: [gb, gbc, sav]) { [weak self] urls in
                    guard let self = self else { return }
                    guard urls.count == 2 else {
                        UIView.makeToast(message: R.string.localizable.transferPakImportError())
                        return
                    }
                    
                    var romPath = ""
                    var savePath = ""
                    let firstPath = urls.first!.path
                    let firstPathExtension = firstPath.pathExtension.lowercased()
                    if firstPathExtension == "gb" || firstPathExtension == "gbc" {
                        romPath = firstPath
                    } else if firstPathExtension == "sav" {
                        savePath = firstPath
                    } else {
                        UIView.makeToast(message: R.string.localizable.transferPakImportError())
                        return
                    }
                    
                    let lastPath = urls.last!.path
                    let lastPathExtension = lastPath.pathExtension.lowercased()
                    if romPath.isEmpty {
                        if lastPathExtension == "gb" || lastPathExtension == "gbc" {
                            romPath = lastPath
                        } else {
                            UIView.makeToast(message: R.string.localizable.transferPakImportError())
                            return
                        }
                    } else {
                        if lastPathExtension == "sav" {
                            savePath = lastPath
                        } else {
                            UIView.makeToast(message: R.string.localizable.transferPakImportError())
                            return
                        }
                    }
                    
                    if let game = self.game {
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: romPath), to: URL(fileURLWithPath: game.romUrl.path + ".gb"), shouldReplace: true)
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: savePath), to: URL(fileURLWithPath: game.romUrl.path + ".sav"), shouldReplace: true)
                        self.transferPakButton.titleLabel.text = "Transfer Pak\n\(R.string.localizable.transferPakOn())"
                        UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                    }
                    
                }
            }
        })
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            //关闭Transfer Pak
            if let game = self.game {
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: game.romUrl.path + ".gb"))
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: game.romUrl.path + ".sav"))
                self.transferPakButton.titleLabel.text = "Transfer Pak\n\(R.string.localizable.transferPakOff())"
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.transferPakDesc(), children: actions))
        return view
    }()
    
    private lazy var transferPakButton: SymbolButton = {
        var state = "\n" + R.string.localizable.transferPakOff()
        if let game = self.game, game.hasTransferPak {
            state = "\n" + R.string.localizable.transferPakOn()
        }
        let view = SymbolButton(symbol: .arrowshapeZigzagForward, title: "Transfer Pak\(state)", horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.transferPakContextMenuButton.triggerTapGesture()
        }
        return view
    }()
    
    private lazy var startGameButton: SymbolButton = {
        let view = SymbolButton(symbol: .playFill)
        view.backgroundColor = Constants.Color.Main
        view.layerCornerRadius = Constants.Size.ItemHeightMid/2
        view.addTapGesture { [weak self] gesture in
            guard let self = self, let game = self.game else { return }
            PlayViewController.startGame(game: game)
        }
        return view
    }()
    
    var didSegmentChange: ((_ index: Int)->Void)?
    lazy var segmentView: BetterSegmentedControl = {
        let titles = [R.string.localizable.readySegmentManualSave(), R.string.localizable.readySegmentAutoSave()]
        let segments = LabelSegment.segments(withTitles: titles,
                                             normalFont: Constants.Font.body(),
                                             normalTextColor: Constants.Color.LabelSecondary,
                                            selectedTextColor: Constants.Color.LabelPrimary)
        let options: [BetterSegmentedControl.Option] = [
            .backgroundColor(Constants.Color.BackgroundSecondary),
            .indicatorViewInset(5),
            .indicatorViewBackgroundColor(Constants.Color.BackgroundTertiary),
            .cornerRadius(16)
        ]
        let view = BetterSegmentedControl(frame: .zero,
                                          segments: segments,
                                          options: options)
        
        view.on(.valueChanged) { [weak self] sender, forEvent in
            guard let self = self, let index = (sender as? BetterSegmentedControl)?.index else { return }
            UIDevice.generateHaptic()
            self.didSegmentChange?(index)
        }
        
        return view
    }()
    
    private class GameInfoSymbolButton: SymbolButton {}
    var didDeleteSaveState: (()->Void)?
    private lazy var deleteSaveStateButton: GameInfoSymbolButton = {
        let view = GameInfoSymbolButton(symbol: .trash)
        view.layerCornerRadius = Constants.Size.ItemHeightMin/2
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didDeleteSaveState?()
        }
        return view
    }()
    
    
    
    var game: Game? = nil {
        didSet {
            if let game = game {
                titleTextField.text = game.aliasName ?? game.name
                if let timeAgo = game.latestPlayDate?.timeAgo() {
                    subtitleLabel.text = R.string.localizable.readyGameInfoSubTitle(timeAgo, Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
                } else {
                    subtitleLabel.text = R.string.localizable.readyGameInfoNeverPlayed()
                }
                if game.gameType == ._3ds {
                    update3DSFunctionButton()
                } else if game.gameType == .psp {
                    updatePSPFunctionButton()
                } else if game.gameType == .ss {
                    updateSaturnFunctionButton()
                } else if game.gameType == .ds {
                    updateDSFunctionButton()
                } else if game.gameType == .n64 {
                    updateN64FunctionButton()
                }
            }
        }
    }
    
    func resetForGamingUsing() {
        subviews.forEach {
            if $0 is BetterSegmentedControl {
                $0.snp.remakeConstraints { make in
                    make.top.equalToSuperview().offset(10)
                    make.height.equalTo(50)
                    make.leading.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                    make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                }
            } else if $0 is GameInfoSymbolButton {
                $0.snp.remakeConstraints { make in
                    make.centerY.equalTo(segmentView)
                    make.size.equalTo(Constants.Size.ItemHeightMin)
                    make.leading.equalTo(segmentView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                }
            } else {
                $0.isHidden = true
            }
        }
        backgroundBlurView.isHidden = false
        backgroundBlurView.alpha = 1
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(titleTextField)
        titleTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceHuge)
            make.top.equalToSuperview()
        }
        
        addSubview(editTitleButton)
        editTitleButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.top.equalTo(titleTextField)
            make.leading.equalTo(titleTextField.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        
        addSubview(subtitleIcon)
        subtitleIcon.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeTiny)
            make.leading.equalTo(titleTextField)
            make.top.equalTo(titleTextField.snp.bottom).offset(Constants.Size.ContentSpaceUltraTiny)
        }
        
        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(subtitleIcon)
            make.leading.equalTo(subtitleIcon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        
        addSubview(functionButtonContainerView)
        functionButtonContainerView.snp.makeConstraints { make in
            make.top.equalTo(subtitleIcon.snp.bottom).offset(Constants.Size.ContentSpaceMid)
            make.leading.equalTo(titleTextField)
            make.height.equalTo(Constants.Size.IconSizeHuge.height)
        }
        
        functionButtonContainerView.addSubview(skinButton)
        skinButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeHuge)
        }
        
        functionButtonContainerView.addSubview(cheatCodeButton)
        cheatCodeButton.snp.makeConstraints { make in
            make.leading.equalTo(skinButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeHuge)
        }
        
        addSubview(startGameButton)
        startGameButton.snp.makeConstraints { make in
            make.centerY.equalTo(functionButtonContainerView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.ItemHeightMid)
            make.leading.equalTo(functionButtonContainerView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
        }
        
        addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.top.equalTo(functionButtonContainerView.snp.bottom).offset(29)
            make.height.equalTo(50)
            make.leading.equalTo(functionButtonContainerView)
            make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        
        addSubview(deleteSaveStateButton)
        deleteSaveStateButton.snp.makeConstraints { make in
            make.centerY.equalTo(segmentView)
            make.size.equalTo(Constants.Size.ItemHeightMin)
            make.leading.equalTo(segmentView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalTo(startGameButton)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update3DSFunctionButton() {
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        threeDSModecontextMenuButton.removeFromSuperview()
        threeDSModeButton.removeFromSuperview()
        shaderContextMenuButton.removeFromSuperview()
        shaderButton.removeFromSuperview()
        languageContextMenuButton.removeFromSuperview()
        languageButton.removeFromSuperview()
        rightEyeRenderMenuButton.removeFromSuperview()
        rightEyeRenderButton.removeFromSuperview()
        threeDSAdvancedSettingButton.removeFromSuperview()
        if let lastView = functionButtonContainerView.subviews.last {
            if Settings.defalut.threeDSAdvancedSettingMode {
                functionButtonContainerView.addSubview(threeDSAdvancedSettingButton)
                threeDSAdvancedSettingButton.snp.makeConstraints { make in
                    make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                    make.trailing.equalToSuperview()
                }
                
            } else {
                //JIT按钮
                functionButtonContainerView.addSubview(jitContextMenuButton)
                functionButtonContainerView.addSubview(jitButton)
                jitButton.snp.makeConstraints { make in
                    make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                jitContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(jitButton)
                }
                
                //模式选择按钮
                functionButtonContainerView.addSubview(threeDSModecontextMenuButton)
                functionButtonContainerView.addSubview(threeDSModeButton)
                threeDSModeButton.snp.makeConstraints { make in
                    make.leading.equalTo(jitButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                threeDSModecontextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(threeDSModeButton)
                }
                
                //着色器选择按钮
                functionButtonContainerView.addSubview(shaderContextMenuButton)
                functionButtonContainerView.addSubview(shaderButton)
                shaderButton.snp.makeConstraints { make in
                    make.leading.equalTo(threeDSModeButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                shaderContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(shaderButton)
                }
                
                //语言选择按钮
                functionButtonContainerView.addSubview(languageContextMenuButton)
                functionButtonContainerView.addSubview(languageButton)
                languageButton.snp.makeConstraints { make in
                    make.leading.equalTo(shaderButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                languageContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(languageButton)
                }
                
                //右眼渲染按钮
                functionButtonContainerView.addSubview(rightEyeRenderMenuButton)
                functionButtonContainerView.addSubview(rightEyeRenderButton)
                rightEyeRenderButton.snp.makeConstraints { make in
                    make.leading.equalTo(languageButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                    make.trailing.equalToSuperview()
                }
                rightEyeRenderMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(rightEyeRenderButton)
                }
            }
        }
    }
    
    private func updatePSPFunctionButton() {
        if let lastView = functionButtonContainerView.subviews.last {
            //语言选择按钮
            functionButtonContainerView.addSubview(languageContextMenuButton)
            functionButtonContainerView.addSubview(languageButton)
            languageButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            languageContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(languageButton)
            }
        }
    }
    
    private func updateSaturnFunctionButton() {
        guard let game else { return }
        if game.defaultCore == 0 {
            cheatCodeButton.removeFromSuperview()
        }
        if game.defaultCore == 0, let lastView = functionButtonContainerView.subviews.last {
            //语言选择按钮
            functionButtonContainerView.addSubview(languageContextMenuButton)
            functionButtonContainerView.addSubview(languageButton)
            languageButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            languageContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(languageButton)
            }
        }
    }
    
    private func updateDSFunctionButton() {
        if let lastView = functionButtonContainerView.subviews.last {
            //语言选择按钮
            functionButtonContainerView.addSubview(languageContextMenuButton)
            functionButtonContainerView.addSubview(languageButton)
            languageButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            languageContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(languageButton)
            }
        }
    }
    
    private func updateN64FunctionButton() {
        if let lastView = functionButtonContainerView.subviews.last {
            //语言选择按钮
            functionButtonContainerView.addSubview(transferPakContextMenuButton)
            functionButtonContainerView.addSubview(transferPakButton)
            transferPakButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            transferPakContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(transferPakButton)
            }
        }
    }
    
}
