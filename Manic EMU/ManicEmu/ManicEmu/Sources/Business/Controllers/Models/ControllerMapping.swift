//
//  ControllerMapping.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import RealmSwift
import ManicEmuCore
import IceCream

extension ControllerMapping: CKRecordConvertible & CKRecordRecoverable {}

class ControllerMapping: Object, ObjectUpdatable {
    ///主键 由创建时间戳ms来生成
    @Persisted(primaryKey: true) var id: Int = PersistedKit.incrementID
    ///控制器名称 相同型号的控制器会使用这份映射 无法避免
    @Persisted var controllerName: String
    ///游戏平台类型
    @Persisted var gameType: GameType
    ///映射的储存信息
    @Persisted var mapping: String
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
        
    var inputMapping: GameControllerInputMappingBase? {
        try? GameControllerInputMapping(mapping: mapping)
    }
}

extension GameControllerInputMapping {
    init(mapping: String) throws {
        let data = mapping.data(using: .utf8)!
        
        let decoder = PropertyListDecoder()
        self = try decoder.decode(GameControllerInputMapping.self, from: data)
    }
    
    func genMapping() -> String {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        if let data = try? encoder.encode(self), let mapping = String(data: data, encoding: .utf8) {
            return mapping
        }
        return ""
    }
}
