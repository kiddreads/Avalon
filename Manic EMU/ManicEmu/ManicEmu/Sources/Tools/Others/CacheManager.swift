//
//  CacheManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Tiercel

struct CacheManager {
    static func clear(completion: (()->Void)? = nil) {
        DispatchQueue.global().async {
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.PasteWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.UploadWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.ShareWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.SMBWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.SaveStateWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.ZipWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.DropWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.ThreeDSStateLoad))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Screenshot))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Temp))
            try? FileManager.default.createDirectory(atPath: Constants.Path.Temp, withIntermediateDirectories: true)
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Document.appendingPathComponent("wpkdata")))
            try? FileManager.default.createDirectory(atPath: Constants.Path.Screenshot, withIntermediateDirectories: true)
            let manager = DownloadManager.shared.sessionManager
            manager.tasks.filter({ $0.status == .succeeded }).forEach { manager.remove($0.url) }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    static var totleSize: String? {
        let size = folderSize(atPath: Constants.Path.PasteWorkSpace) +
        folderSize(atPath: Constants.Path.UploadWorkSpace) +
        folderSize(atPath: Constants.Path.ShareWorkSpace) +
        folderSize(atPath: Constants.Path.DownloadWorkSpace) +
        folderSize(atPath: Constants.Path.SMBWorkSpace) +
        folderSize(atPath: Constants.Path.SaveStateWorkSpace) +
        folderSize(atPath: Constants.Path.ZipWorkSpace) +
        folderSize(atPath: Constants.Path.ThreeDSStateLoad)
        return FileType.humanReadableFileSize(size)
    }
    
    static func folderSize(atPath path: String) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return totalSize
        }
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 递归获取子文件夹的大小
                    totalSize += folderSize(atPath: itemPath)
                } else {
                    // 获取文件的大小
                    if let attributes = try? fileManager.attributesOfItem(atPath: itemPath),
                       let fileSize = attributes[.size] as? UInt64 {
                        totalSize += fileSize
                    }
                }
            }
        }
        return totalSize
    }
}
