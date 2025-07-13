//
//  FileType.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore

enum FileType {
    case game
    case gameSave
    case skin
    case zip
    
    init?(fileExtension: String) {
        if FileType.skin.extensions.contains(fileExtension.lowercased()) {
            self = .skin
        } else if FileType.gameSave.extensions.contains(fileExtension.lowercased()) {
            self = .gameSave
        } else if FileType.game.extensions.contains(fileExtension.lowercased()) {
            self = .game
        } else if FileType.zip.extensions.contains(fileExtension) {
            self = .zip
        } else {
            return nil
        }
    }
    
    static func allSupportFileExtension() -> [String] {
        FileType.game.extensions + FileType.gameSave.extensions + FileType.skin.extensions + FileType.zip.extensions
    }
    
    var extensions: [String] {
        FileType.getFileExtensions(for: self)
    }
    
    private static func getFileExtensions(for fileType: FileType) -> [String] {
        var results: [String] = []
        if let declarations: [[String: Any]] = Constants.Config.value(forKey: "UTExportedTypeDeclarations") {
            for declaration in declarations {
                let prefixItem: String
                switch fileType {
                case .game:
                    prefixItem = "game"
                case .gameSave:
                    prefixItem = "gamesave"
                case .skin:
                    prefixItem = "skin"
                case .zip:
                    prefixItem = "zip"
                }
                if let identifier = declaration["UTTypeIdentifier"] as? String,
                   identifier.contains("public.aoshuang.\(prefixItem)") {
                    if let specification = declaration["UTTypeTagSpecification"] as? [String: Any], let extensions = specification["public.filename-extension"] as? [String] {
                        results.append(contentsOf: extensions.map { $0.lowercased() }) 
                    }
                }
            }
        }
        return results
    }
    
    static func get3DSExtensions() -> [String] {
        var results: [String] = []
        if let declarations: [[String: Any]] = Constants.Config.value(forKey: "UTExportedTypeDeclarations") {
            for declaration in declarations {
                if let identifier = declaration["UTTypeIdentifier"] as? String,
                   identifier.contains("public.aoshuang.game.3ds") {
                    if let specification = declaration["UTTypeTagSpecification"] as? [String: Any], let extensions = specification["public.filename-extension"] as? [String] {
                        results.append(contentsOf: extensions.map { $0.lowercased() })
                    }
                }
            }
        }
        return results
    }
    
    static func humanReadableFileSize(_ sizeInBytes: UInt64) -> String? {
        let units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
        var size = Double(sizeInBytes)
        var unitIndex = 0

        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }

        if size == 0 {
            return nil
        }
        return String(format: "%.2f %@", size, units[unitIndex])
    }
}
