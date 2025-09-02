//
//  GameCheat.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import IceCream

extension GameCheat: CKRecordConvertible & CKRecordRecoverable {}

class GameCheat: Object {
    ///主键 由创建时间戳ms来生成
    @Persisted(primaryKey: true) var id: Int = PersistedKit.incrementID
    ///名称
    @Persisted var name: String
    ///代码
    @Persisted var code: String
    ///类型
    @Persisted var type: String
    ///是否启用
    @Persisted var activate: Bool = false
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
}
