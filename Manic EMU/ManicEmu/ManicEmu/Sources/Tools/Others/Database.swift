//
//  Database.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import IceCream
import ZIPFoundation

struct Database {
    static func setup(completion: (()->Void)? = nil) {
        do {
            let realm = Database.realm
            
            //init Prefference
            let prefference = realm.object(ofType: Prefference.self, forPrimaryKey: Prefference.defaultName)
            if prefference == nil {
                try? realm.write {
                    realm.add(Prefference())
                }
            }
            
            //If the setting has already been initialized, it won't be initialized again.
            let oldSettings = realm.object(ofType: Settings.self, forPrimaryKey: Settings.defaultName)
            if oldSettings == nil {
                Log.debug("设置不存在 初始化设置")
                let settings = Settings()
                
                try realm.write {
                    realm.add(generateDefaultSkins())
                    realm.add(settings)
                }
            } else if let _ = oldSettings {
                //The setting already exists. Check whether the number of skins matches the number of emulators. If they don't match, you'll need to update the default skin.
                let defaultSkins = realm.objects(Skin.self).where { $0.skinType == .default }
                let defaultSkinsCount = defaultSkins.count
                if defaultSkinsCount != System.allCases.filter({ !$0.gameType.externalType }).count {
                    Log.debug("更新设置 新增皮肤")
                    //Regenerate the default skin list
                    let genDefaultSkins = generateDefaultSkins()
                    
                    //Check if the Preference has configured a default skin. If so, it needs to be updated to the new skin ID.
                    defaultSkins.forEach({ oldSkin in
                        genDefaultSkins.forEach({ newSkin in
                            if newSkin.identifier == oldSkin.identifier && newSkin.id != oldSkin.id {
                                Prefference.defalut.replaceValue(kind: .skin, value: oldSkin.id, replace: newSkin.id)
                            }
                        })
                    })
                    
                    //Remove the old default skin.
                    try? realm.write {
                        realm.delete(defaultSkins)
                    }
                    
                    //Add new default skin
                    try? realm.write {
                        realm.add(genDefaultSkins)
                    }
                }
            }
            
            //新增其他皮肤
            addEmbedSkins()
            
            //处理主题
            let theme = realm.object(ofType: Theme.self, forPrimaryKey: Theme.defaultName)
            if theme == nil {
                //初始化主题
                let newTheme = Theme()
                try? realm.write({
                    realm.add(newTheme)
                })
            } else if let theme {
                //检查是否新增了平台
                let platformOrder = theme.platformOrder
                let allPlatforms = System.allCases.map { $0.gameType.localizedShortName }
                var needToAdd = [String]()
                if platformOrder.count != allPlatforms.count {
                    //需要新增平台
                    for platform in allPlatforms {
                        if !(platformOrder.contains(where: { $0 == platform })) {
                            needToAdd.append(platform)
                        }
                    }
                    try? realm.write({
                        theme.platformOrder.insert(contentsOf: needToAdd, at: 0)
                    })
                }
                if theme.gamesPerRow == 0 {
                    try? realm.write({
                        theme.gamesPerRow = 2
                    })
                }
            }
            
            //检查是否有游戏的封面还没有匹配
            let games = realm.objects(Game.self).where {
                !$0.isDeleted &&
                $0.gameCover == nil &&
                $0.onlineCoverUrl == nil &&
                !$0.hasCoverMatch
            }
            games.forEach { game in
                OnlineCoverManager.shared.addCoverMatch(OnlineCoverManager.CoverMatch(game: game))
            }
            
            if let systemCoreVersion = UserDefaults.standard.string(forKey: R.DefaultKey.SystemCoreVersion) {
                //如果存在版本记录，说明是旧版本升级到新版本，需要处理一下
                let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
                
                if systemCoreVersionNumber < 141 {
                    //调整1.4.0的gameType问题
                    let mds = realm.objects(Game.self).where { $0.gameType == .md && ($0.fileExtension.equals("chd", options: .caseInsensitive) || $0.fileExtension.equals("32x", options: .caseInsensitive)) }
                    if mds.count > 0 {
                        try? realm.write {
                            for md in mds {
                                if md.fileExtension.lowercased() == "chd" {
                                    md.gameType = .mcd
                                } else if md.fileExtension.lowercased() == "32x" {
                                    md.gameType = ._32x
                                }
                            }
                        }
                    }
                }
                
                
                if systemCoreVersionNumber < 142 {
                    //调整土星的默认使用核心
                    //只有1.4.2之前的版本需要处理 将所有已经导入的SS核心默认使用Yabause
                    let games = realm.objects(Game.self).where({ $0.gameType == .ss })
                    if games.count > 0 {
                        try? realm.write({
                            for ss in games {
                                ss.defaultCore = 1
                            }
                        })
                    }
                }
                
                if systemCoreVersionNumber < 150 {
                    //将所有GB和GBC进行分离
                    let gbcs = realm.objects(Game.self).where({ $0.gameType == .gbc }).filter({ $0.fileExtension.lowercased() == "gb" })
                    if gbcs.count > 0 {
                        try? realm.write({
                            for gbc in gbcs {
                                gbc.gameType = .gb
                            }
                        })
                    }
                }
                
                if systemCoreVersionNumber < 155 {
                    let allSkins = realm.objects(Skin.self)
                    //调整skinType
                    //.buildIn的值等于原来的.manic .import等于原来的.delta
                    let oldSkins = allSkins.where({ $0.skinType == .buildIn || $0.skinType == .import })
                    try? realm.write({
                        for oldSkin in oldSkins {
                            if !oldSkin.isFlexSkin {
                                oldSkin.skinType = .import
                            }
                        }
                    })
                    
                    //修复可能皮肤的identifier相同的错误
                    let defaultSkins = allSkins.where({ $0.skinType == .default })
                    for defaultSkin in defaultSkins {
                        let otherSkins = allSkins.where({ $0.identifier == defaultSkin.identifier && $0.skinType != .default && $0.gameType == defaultSkin.gameType })
                        if otherSkins.count > 0 {
                            for (index, otherSkin) in otherSkins.enumerated() {
                                try? realm.write {
                                    otherSkin.identifier = otherSkin.identifier + "_\(index)"
                                }
                            }
                        }
                    }
                }
                
                if systemCoreVersionNumber < 170 {
                    //调整snes gba的默认核心
                    let games = realm.objects(Game.self).where({ $0.gameType == .snes || $0.gameType == .gba })
                    if games.count > 0 {
                        try? realm.write({
                            for g in games {
                                if g.gameType == .gba, g.gameSaveStates.count > 0 {
                                    g.defaultCore = 1
                                } else if g.gameType == .snes {
                                    //如果将snes游戏迁移至bsnes 则将存档文件从Snes9x迁移到bsnes
                                    let oldSaveUrl = URL(fileURLWithPath: R.Path.Snes9x.appendingPathComponent("\(g.name).srm"))
                                    if FileManager.default.fileExists(atPath: oldSaveUrl.path) {
                                        try? FileManager.safeMoveItem(at: oldSaveUrl, to: URL(fileURLWithPath: R.Path.bsnes.appendingPathComponent("\(g.name).srm")), shouldReplace: true)
                                    }
                                }
                            }
                        })
                        
                        //将GBA即时存档文件都进行核心标记
                        for g in games {
                            if g.gameType == .gba, g.gameSaveStates.count > 0 {
                                for s in g.gameSaveStates {
                                    s.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: 1)
                                }
                            }
                        }
                    }
#if SIDE_LOAD
                    //Sideload版本默认使用Picodrive
                    let picodriveGames = realm.objects(Game.self).where({ $0.gameType == .md || $0.gameType == .ms || $0.gameType == .gg || $0.gameType == .sg1000 })
                    if picodriveGames.count > 0 {
                        try? realm.write({
                            for g in picodriveGames {
                                g.defaultCore = 1
                            }
                        })
                        for g in picodriveGames {
                            if g.gameSaveStates.count > 0 {
                                for s in g.gameSaveStates {
                                    s.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: 1)
                                }
                            }
                        }
                    }
#else
                    let picodriveGames = realm.objects(Game.self).where({ $0.gameType == .md || $0.gameType == .ms || $0.gameType == .gg || $0.gameType == .sg1000 })
                    if picodriveGames.count > 0 {
                        for g in picodriveGames {
                            //将picodrive的存档转移到Gearsystem或ClownMDEmu的目录
                            let oldSaveUrl = URL(fileURLWithPath: R.Path.PicoDrive.appendingPathComponent("\(g.name).srm"))
                            if FileManager.default.fileExists(atPath: oldSaveUrl.path) {
                                try? FileManager.safeMoveItem(at: oldSaveUrl, to: g.gameSaveUrl, shouldReplace: true)
                            }
                            //将旧的即时存档全部编辑Picodrive生成
                            if g.gameSaveStates.count > 0 {
                                for s in g.gameSaveStates {
                                    s.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: 1)
                                }
                            }
                        }
                    }
#endif
                }
                
                //1.7.3之后将nes和fds区分开
                if systemCoreVersionNumber <= 173 {
                    var needsUpdate: Bool = systemCoreVersionNumber < 173
                    if !needsUpdate {
                        let systemCoreBuildVersion = UserDefaults.standard.integer(forKey: R.DefaultKey.SystemCoreBuildVersion)
                        let appBuildVersion = Int(R.Config.AppBuildVersion)!
                        if appBuildVersion > systemCoreBuildVersion {
                            needsUpdate = true
                        }
                    }
                    
                    if needsUpdate {
                        let nesGames = realm.objects(Game.self).where({ $0.gameType == .nes })
                        for nes in nesGames {
                            if nes.fileExtension.lowercased() == "fds" {
                                try? realm.write({
                                    nes.gameType = .fds
                                })
                            }
                        }
                    }
                }
                
                //修复1.9.1将J2meJS破坏的存档
                if systemCoreVersionNumber < 192 {
                    let games = realm.objects(Game.self).where({ $0.gameType == .j2me || $0.defaultCore == 0 })
                    for game in games {
                        if FileManager.default.fileExists(atPath: game.gameSaveUrl.path),
                           let newSaveUrl = fixJ2meJSSave(fileName: game.fileName, url: game.gameSaveUrl) {
                            try? FileManager.safeMoveItem(at: newSaveUrl, to: game.gameSaveUrl, shouldReplace: true)
                        }
                    }
                }
                
                if systemCoreVersionNumber < 200 {
                    //Migrate skin configuration
                    let games = realm.objects(Game.self).where({ $0.portraitSkin != nil || $0.landscapeSkin != nil })
                    for game in games {
                        if let skin = game.portraitSkin {
                            Prefference.defalut.storePrefference(kind: .skin,
                                                                 storeKey: .orientationKey(gameId: game.id, isLandScape: false),
                                                                 storeValue: skin.id)
                            try? realm.write({
                                game.portraitSkin = nil
                            })
                        }
                        if let skin = game.landscapeSkin {
                            Prefference.defalut.storePrefference(kind: .skin,
                                                                 storeKey: .orientationKey(gameId: game.id, isLandScape: true),
                                                                 storeValue: skin.id)
                            try? realm.write({
                                game.landscapeSkin = nil
                            })
                        }
                    }
                    if let skinConfigs = SkinConfig.deserialize(from: Settings.defalut.skinConfig) {
                        for (gameTypeString, skinId) in skinConfigs.portraitSkins {
                            if let gameType = GameType(shortName: gameTypeString) {
                                Prefference.defalut.storePrefference(kind: .skin,
                                                                     storeKey: .orientationKey(gameType: gameType, isLandScape: false),
                                                                     storeValue: skinId)
                            }
                        }
                        for (gameTypeString, skinId) in skinConfigs.landscapeSkins {
                            if let gameType = GameType(shortName: gameTypeString) {
                                Prefference.defalut.storePrefference(kind: .skin,
                                                                     storeKey: .orientationKey(gameType: gameType, isLandScape: true),
                                                                     storeValue: skinId)
                            }
                        }
                        try? realm.write({
                            Settings.defalut.skinConfig = ""
                        })
                    }
                    
                    //Migrate flexBackground configuration
                    let backgrounds = FlexBackground.getAllBackground()
                    for background in backgrounds {
                        let isLandScape = background.name.contains("landscape")
                        if background.global {
                            Prefference.defalut.storePrefference(kind: .flexBackground,
                                                                 storeKey: .orientationKey(isLandScape: isLandScape),
                                                                 storeValue: background.name)
                            continue
                        } else if background.consoles.count > 0 {
                            for console in background.consoles {
                                if let gameType = GameType(shortName: console) {
                                    Prefference.defalut.storePrefference(kind: .flexBackground,
                                                                         storeKey: .orientationKey(gameType: gameType, isLandScape: isLandScape),
                                                                         storeValue: background.name)
                                }
                            }
                            continue
                        } else {
                            for gameId in background.games {
                                Prefference.defalut.storePrefference(kind: .flexBackground,
                                                                     storeKey: .orientationKey(gameId: gameId, isLandScape: isLandScape),
                                                                     storeValue: background.name)
                            }
                        }
                    }
                    
                    //Migrate shader configuration
                    let shaderGames = realm.objects(Game.self).where({ $0.filterName != nil })
                    for game in shaderGames {
                        if let filterName = game.filterName {
                            Prefference.defalut.storePrefference(kind: .shader,
                                                                 storeKey: .shaderKey(gameId: game.id,
                                                                                      isGlsl: game.supportGlslShaders),
                                                                 storeValue: filterName)
                        }
                    }
                    
                    if let shaderConfig = ShaderConfig.getConfig() {
                        for (platform, shaderPath) in shaderConfig.coreConfigs {
                            if let gameType = GameType(shortName: platform) {
                                let isGlsl = gameType == .n64 && shaderPath.pathExtension.lowercased() == "glslp"
                                Prefference.defalut.storePrefference(kind: .shader,
                                                                     storeKey: .shaderKey(gameType: gameType, isGlsl: isGlsl),
                                                                     storeValue: shaderPath)
                            }
                        }
                        
                        if let globalShaderPath = shaderConfig.globalConfig {
                            let isGlsl = globalShaderPath.pathExtension.lowercased() == "glslp"
                            Prefference.defalut.storePrefference(kind: .shader,
                                                                 storeKey: .shaderKey(isGlsl: isGlsl),
                                                                 storeValue: globalShaderPath)
                        }
                    }
                    
                    //update gamesPerRow 2 to 3 for default
                    if Theme.defalut.gamesPerRow == 2 {
                        Theme.change { realm in
                            Theme.defalut.gamesPerRow = 3
                        }
                    }
                    
                    //The default core for the 3DS has been changed to Azahar.
                    var config = GlobalCoreSwitch.getConfig(realm: realm)
                    if config.getUsingCoreName(gameType: GameType._3ds) == nil {
                        config.setUsingCoreName(gameType: ._3ds, coreName: EmulationCore.Azahar.name)
                    }
                }
            }
            
            //Prevent the game from not being removed after Articbase finishes its work due to an error.
            if let articbase = realm.object(ofType: Game.self, forPrimaryKey: R.Strings.AzaharArticBaseGameID) {
                try? realm.write {
                    realm.delete(articbase)
                }
            }
            
        } catch {
            Log.error("初始化数据错误 \(error)")
        }
        completion?()
    }
    
    static var realm: Realm {
        do {
            return try Realm(configuration: defaultConfig)
        } catch {
            Log.error("生成数据库失败")
        }
        return try! Realm()
    }
    
    private static var defaultConfig: Realm.Configuration {
        var config = Realm.Configuration.defaultConfiguration
        //Configure the database path.
        if !FileManager.default.fileExists(atPath: R.Path.Realm) {
            try? FileManager.default.createDirectory(atPath: R.Path.Realm, withIntermediateDirectories: true)
        }
        config.fileURL = URL(fileURLWithPath: R.Path.RealmFilePath)
        //Configure the database version, and use the app version for control.
        config.schemaVersion = UInt64(R.Config.AppVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
        return config
    }
    
    private static func generateDefaultSkins() -> [Skin] {
        //Add default skin
        var defaultSkins = [Skin]()
        System.allCores.forEach { core in
            let gameType = core.gameType
            if let controllerSkin = ControllerSkin.standardControllerSkin(for: gameType),
               let hash = FileHashUtil.truncatedHash(url: controllerSkin.fileURL) {
                let skin = Skin()
                skin.id = hash
                skin.identifier = controllerSkin.identifier
                skin.name = controllerSkin.name
                skin.fileName = controllerSkin.fileURL.lastPathComponent
                skin.gameType = controllerSkin.gameType
                skin.skinType = .default
                defaultSkins.append(skin)
            }
        }
        return defaultSkins
    }
    
    private static func addEmbedSkins() {
        DispatchQueue.global().async {
            let realm = Database.realm
            let fileManager = FileManager.default
            let resourcePath = R.Path.Resource
            //处理内置Manic皮肤
            if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                let skinNames = contents.filter { $0.hasSuffix(".manicskin") }
                var embedSkins = [Skin]()
                for skinName in skinNames {
                    if let controllerSkin = ControllerSkin(fileURL: URL(fileURLWithPath: resourcePath.appendingPathComponent(skinName))),
                       let hash = FileHashUtil.truncatedHash(url: controllerSkin.fileURL) {
                        if let skin = realm.object(ofType: Skin.self, forPrimaryKey: hash) {
                            Log.debug("皮肤:\(skin.name)已存在")
                        } else {
                            //有可能是更新了皮肤
                            var newSkinType = SkinType.buildIn
                            let oldSkins = realm.objects(Skin.self).where { $0.identifier == controllerSkin.identifier }
                            if oldSkins.count > 0 {
                                newSkinType = oldSkins.first!.skinType
                                Log.debug("\(controllerSkin.name) 皮肤进行了更新，移除旧的皮肤")
                                oldSkins.forEach {
                                    if let filePath = $0.skinData?.filePath {
                                        try? FileManager.safeRemoveItem(at: filePath)
                                    }
                                }
                                let assets = oldSkins.compactMap({ $0.skinData })
                                try? realm.write {
                                    if assets.count > 0 {
                                        realm.delete(assets)
                                    }
                                    realm.delete(oldSkins)
                                }
                            }
                            
                            let skin = Skin()
                            skin.id = hash
                            skin.identifier = controllerSkin.identifier
                            skin.name = controllerSkin.name
                            skin.fileName = controllerSkin.fileURL.lastPathComponent
                            skin.gameType = controllerSkin.gameType
                            skin.skinType = newSkinType
                            if newSkinType != .default {
                                skin.skinData = CreamAsset.create(objectID: skin.id, propName: "skinData", url: controllerSkin.fileURL)
                            }
                            embedSkins.append(skin)
                            
                            //The skin file has been updated, so I'm trying to update the skin ID configured in Preferences.
                            oldSkins.forEach({
                                Prefference.defalut.replaceValue(kind: .skin, value: $0.id, replace: skin.id)
                            })
                            
                        }
                    }
                }
                if embedSkins.count > 0 {
                    try? realm.write({
                        realm.add(embedSkins)
                    })
                }
            }
            
            //PlayCase皮肤
#if !SIDE_LOAD
            if !UserDefaults.standard.bool(forKey: R.DefaultKey.HasImportedPlayCaseSkin) {
                if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath.appendingPathComponent("PlayCase")) {
                    let skinNames = contents.filter { $0.hasSuffix(".playcase") }
                    var embedSkins = [Skin]()
                    for skinName in skinNames {
                        if let controllerSkin = ControllerSkin(fileURL: URL(fileURLWithPath: resourcePath.appendingPathComponent("PlayCase").appendingPathComponent(skinName))),
                           let hash = FileHashUtil.truncatedHash(url: controllerSkin.fileURL) {
                            let skins = realm.objects(Skin.self)
                            
                            if let skin = skins.first(where: { $0.identifier == controllerSkin.identifier }) {
                                Log.debug("PlayCase皮肤:\(skin.name)已存在")
                                if skin.skinType != .playcase {
                                    Log.debug("用户自行导入过PlayCase皮肤，现在对其进行更新")
                                    _ = try? realm.write({
                                        skin.skinType == .playcase
                                    })
                                }
                            } else {
                                let skin = Skin()
                                skin.id = hash
                                skin.identifier = controllerSkin.identifier
                                skin.name = controllerSkin.name
                                skin.fileName = controllerSkin.fileURL.lastPathComponent
                                skin.gameType = controllerSkin.gameType
                                skin.skinType = .playcase
                                skin.skinData = CreamAsset.create(objectID: skin.id, propName: "skinData", url: controllerSkin.fileURL)
                                embedSkins.append(skin)
                                Log.debug("开始集成PlayCase皮肤:\(skin.name)")
                            }
                        }
                    }
                    if embedSkins.count > 0 {
                        try? realm.write({
                            realm.add(embedSkins)
                        })
                    }
                }
                UserDefaults.standard.set(true, forKey: R.DefaultKey.HasImportedPlayCaseSkin)
            }
#endif
        }
    }
    
    static func fixJ2meJSSave(fileName: String, url: URL) -> URL? {
        let zipUrl = URL(fileURLWithPath: R.Path.Cache.appendingPathComponent("\(fileName)"))
        let tempWorkSpaceUrl = URL(fileURLWithPath: R.Path.Cache.appendingPathComponent(fileName.deletingPathExtension))
        do {
            try FileManager.default.unzipItem(at: url, to: tempWorkSpaceUrl)
        } catch {
            Log.debug("not j2mejs zip save file")
            return nil
        }
        
        let oldRecordStoreJsonPath = tempWorkSpaceUrl.path.appendingPathComponent("metadata/RecordStore_game.0.json")
        let oldRecordStoreSavePath = tempWorkSpaceUrl.path.appendingPathComponent("saves/RecordStore_game.0")
        let newRecordStoreJsonPath = tempWorkSpaceUrl.path.appendingPathComponent("metadata/RecordStore_\(fileName)_game.0.json")
        let newRecordStoreSavePath = tempWorkSpaceUrl.path.appendingPathComponent("saves/RecordStore_\(fileName)_game.0")
        
        if FileManager.default.fileExists(atPath: newRecordStoreJsonPath) {
            //save file correct
            return url
        } else {
            //This is an old save—we should try to upgrade it.
            do {
                //1、gen metadata/RecordStore_xxx.jar_game.0.json and adjust the path order correctly.
                if var json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: oldRecordStoreJsonPath))) as? [String: Any] {
                    json["path"] = "/RecordStore/\(fileName)/game.0"
                    if let jsonData = try? JSONSerialization.data(withJSONObject: json) {
                        try jsonData.write(to: URL(fileURLWithPath: newRecordStoreJsonPath))
                        //2、gen metadata/RecordStore_xxx.jar_game.0.json
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: oldRecordStoreSavePath), to: URL(fileURLWithPath: newRecordStoreSavePath), shouldReplace: true)
                        //3、remove old save
                        try FileManager.safeRemoveItem(at: zipUrl)
                        //4、gen new save
                        try FileManager.default.zipItem(at: tempWorkSpaceUrl, to: zipUrl, shouldKeepParent: false)
                    }
                }
            } catch {
                Log.debug("update J2meJS saves failed:\(error)")
                return nil
            }
        }
        //4、Clear Cache
        try? FileManager.default.removeItem(at: tempWorkSpaceUrl)
        return zipUrl
    }
}
