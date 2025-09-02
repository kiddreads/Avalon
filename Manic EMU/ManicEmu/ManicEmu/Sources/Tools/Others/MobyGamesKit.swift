//
//  MobyGamesKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/30.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SQLite
import Fuse

struct MobyGamesKit {
    struct Result {
        var name: String
        var url: String
    }
    
    static func getGameInfoUrl(game: Game, completion: ((URL)->Void)? = nil) {
        let gameTypeName = game.gameType.localizedShortName
        let searchPattern = game.translatedName ?? game.aliasName ?? game.name
        DispatchQueue.global().async {
            do {
                let db = try Connection(Constants.Path.GamesDB)
                try db.key(Constants.Cipher.UnzipKey)
                let table = Table(gameTypeName)
//                let id = SQLite.Expression<Int>("id")
                let url = SQLite.Expression<String>("url")
                let name = SQLite.Expression<String>("name")
//                let year = SQLite.Expression<Int>("year")
                let allGameInfos = try db.prepare(table)
                let fuse = Fuse()
                let pattern = fuse.createPattern(from: searchPattern)
                let matchList = allGameInfos.map({ Result(name: $0[name], url: $0[url]) })
                if let result = matchList.min(by: {
                    if let result0 = fuse.search(pattern, in: $0.name) {
                        if let result1 = fuse.search(pattern, in: $1.name) {
                            return result0.score < result1.score
                        } else {
                            return true
                        }
                    } else if let _ = fuse.search(pattern, in: $1.name) {
                        return false
                    } else {
                        return true
                    }
                }) {
                    if let score = fuse.search(pattern, in: result.name)?.score, score < 0.35 {
                        //匹配结果OK
                        DispatchQueue.main.async {
                            completion?(URL(string: result.url) ?? Constants.URLs.MobyGames)
                        }
                    } else {
                        //匹配结果的相似度太低 放弃
                        DispatchQueue.main.async {
                            completion?(Constants.URLs.MobyGames)
                        }
                    }
                } else {
                    //无法匹配
                    DispatchQueue.main.async {
                        completion?(Constants.URLs.MobyGames)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(Constants.URLs.MobyGames)
                }
            }
        }
    }
}
