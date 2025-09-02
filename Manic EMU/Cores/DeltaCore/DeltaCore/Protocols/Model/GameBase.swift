//
//  GameProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import Foundation

public protocol GameBase
{
    var fileURL: URL { get }
    var gameSaveURL: URL { get }
    
    var type: GameType { get }
}

public extension GameBase
{
    var gameSaveURL: URL {
        let core = ManicEmu.core(for: self.type)
        let fileExtension = core?.gameSaveExtension ?? "sav"
        if let customSavePath = core?.gameSaveCustomPath {
            //使用自定义存档路径
            let gameName = self.fileURL.deletingPathExtension().lastPathComponent
            let gameSaveUrl = URL(fileURLWithPath: customSavePath + "/\(gameName).\(fileExtension)" )
            return gameSaveUrl
        } else {
            let gameURL = self.fileURL.deletingPathExtension()
            let gameSaveURL = gameURL.appendingPathExtension(fileExtension)
            return gameSaveURL
        }
    }
}
