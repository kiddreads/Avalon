//
//  FileManagerExtensions.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

extension FileManager {
    static func safeMoveItem(at srcURL: URL, to dstURL: URL, shouldReplace: Bool = false) throws {
        do {
            try completePath(url: dstURL)
            if shouldReplace {
                try safeRemoveItem(at: dstURL)
            }
            try FileManager.default.moveItem(at: srcURL, to: dstURL)
        } catch {
            throw error
        }
    }
    
    static func safeCopyItem(at srcURL: URL, to dstURL: URL, shouldReplace: Bool = false) throws {
        do {
            try completePath(url: dstURL)
            if shouldReplace {
                try safeRemoveItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch {
            throw error
        }
    }
    
    static func safeRemoveItem(at url: URL) throws {
        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: url.path) {
                try manager.removeItem(at: url)
            }
        } catch {
            throw error
        }
    }
    
    static func completePath(url: URL) throws {
        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: url.path) {
                return
            } else {
                if isDirectory(at: url) {
                    try manager.createDirectory(at: url, withIntermediateDirectories: true)
                } else {
                    try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                }
            }
        } catch {
            throw error
        }
    }
    
    static func isDirectory(at url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues.isDirectory == true
        } catch {
            return false
        }
    }
}
