//
//  GlobalCoreSwitch.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import SmartCodable
import ManicEmuCore
import RealmSwift

struct GlobalCoreSwitch: SmartCodable, Equatable {
    var globalCoreConfigs = [String: String]()
    
    func getUsingCoreName(gameType: GameType) -> String? {
        return globalCoreConfigs[gameType.localizedShortName]
    }
    
    func getUsingCoreIndex(gameType: GameType) -> Int? {
        let coreName = getUsingCoreName(gameType: gameType)
        return gameType.supportCores.firstIndex(where: { $0 == coreName })
    }
    
    mutating func setUsingCoreName(gameType: GameType, coreName: String) {
        globalCoreConfigs[gameType.localizedShortName] = coreName
        Self.updateConfig(self)
    }
    
    static func getConfig(realm: Realm? = nil) -> GlobalCoreSwitch {
        var coreConfig: String? = nil
        if let realm, let settings = realm.object(ofType: Settings.self, forPrimaryKey: Settings.defaultName) {
            coreConfig = settings.getExtraString(key: ExtraKey.globalCoreConfigs.rawValue)
        } else {
            coreConfig = Settings.defalut.getExtraString(key: ExtraKey.globalCoreConfigs.rawValue)
        }
        
        if let coreConfig, let config = GlobalCoreSwitch.deserialize(from: coreConfig) {
#if DEBUG
            Log.debug("获取GlobalCoreSwitch配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            return config
        }
        Log.debug("获取默认GlobalCoreSwitch配置")
        
        var configs = [String: String]()
        let gameTypes = System.allCases.map({ $0.gameType }).filter({ $0.supportCores.count > 0 })
        for gameType in gameTypes {
            configs[gameType.localizedShortName] = gameType.supportCores.first(where: { !$0.isEmpty })
        }
        return GlobalCoreSwitch(globalCoreConfigs: configs)
    }
    
    static func updateConfig(_ config: GlobalCoreSwitch) {
        if let jsonString = config.toJSONString() {
#if DEBUG
            Log.debug("保存GlobalCoreSwitch配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            Settings.defalut.updateExtra(key: ExtraKey.globalCoreConfigs.rawValue, value: jsonString)
        }
    }
}
