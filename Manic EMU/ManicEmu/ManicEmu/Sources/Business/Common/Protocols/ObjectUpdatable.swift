//
//  ObjectUpdatable.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import RealmSwift

protocol ObjectUpdatable {
    static func change(action: ((_ realm: Realm) throws ->Void))
}

extension ObjectUpdatable {
    static func change(action: ((_ realm: Realm) throws ->Void)) {
        do {
            let realm = Database.realm
            try realm.write {
                try action(realm)
            }
        } catch {
            Log.error("更新\(type(of: self))失败")
        }
    }
}
