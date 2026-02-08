// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// Utility class to help access and manage Dolphin configuration INI files
@objc class ConfigFileManager: NSObject {
    
    /// Get the path to the Config directory
    @objc static func getConfigDirectory() -> String {
        return UserFolderUtil.getUserFolder().stringByAppendingPathComponent("Config")
    }
    
    /// Get the path to a specific config file
    @objc static func getConfigFilePath(filename: String) -> String {
        return getConfigDirectory().stringByAppendingPathComponent(filename)
    }
    
    /// Common config file paths
    @objc static var gfxConfigPath: String {
        return getConfigFilePath(filename: "GFX.ini")
    }
    
    @objc static var dolphinConfigPath: String {
        return getConfigFilePath(filename: "Dolphin.ini")
    }
    
    @objc static var gcPadConfigPath: String {
        return getConfigFilePath(filename: "GCPadNew.ini")
    }
    
    @objc static var wiimoteConfigPath: String {
        return getConfigFilePath(filename: "WiimoteNew.ini")
    }
    
    @objc static var loggerConfigPath: String {
        return getConfigFilePath(filename: "Logger.ini")
    }
    
    /// Check if a config file exists
    @objc static func configFileExists(_ filename: String) -> Bool {
        let path = getConfigFilePath(filename: filename)
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Read the contents of a config file
    @objc static func readConfigFile(_ filename: String) -> String? {
        let path = getConfigFilePath(filename: filename)
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
    
    /// Write contents to a config file
    @objc static func writeConfigFile(_ filename: String, contents: String) -> Bool {
        let path = getConfigFilePath(filename: filename)
        
        // Ensure Config directory exists
        let configDir = getConfigDirectory()
        if !FileManager.default.fileExists(atPath: configDir) {
            try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        do {
            try contents.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error writing config file \(filename): \(error)")
            return false
        }
    }
    
    /// Copy a template config file to the Config directory
    @objc static func installTemplateConfig(templatePath: String, configFilename: String, overwrite: Bool = false) -> Bool {
        let destPath = getConfigFilePath(filename: configFilename)
        
        // Don't overwrite unless explicitly requested
        if !overwrite && FileManager.default.fileExists(atPath: destPath) {
            print("Config file \(configFilename) already exists. Skipping.")
            return false
        }
        
        do {
            // Ensure Config directory exists
            let configDir = getConfigDirectory()
            if !FileManager.default.fileExists(atPath: configDir) {
                try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Copy the file
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(atPath: templatePath, toPath: destPath)
            print("Successfully installed \(configFilename)")
            return true
        } catch {
            print("Error installing template config \(configFilename): \(error)")
            return false
        }
    }
    
    /// List all INI files in the Config directory
    @objc static func listConfigFiles() -> [String] {
        let configDir = getConfigDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: configDir) else {
            return []
        }
        return files.filter { $0.hasSuffix(".ini") }
    }
    
    /// Export config file to Documents directory for easy access via Files app
    @objc static func exportConfigToDocuments(_ filename: String) -> String? {
        let sourcePath = getConfigFilePath(filename: filename)
        let documentsPath = UserFolderUtil.getUserFolder()
        let destPath = documentsPath.stringByAppendingPathComponent("Exported_\(filename)")
        
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destPath)
            return destPath
        } catch {
            print("Error exporting config: \(error)")
            return nil
        }
    }
    
    /// Import config file from Documents directory
    @objc static func importConfigFromDocuments(_ filename: String) -> Bool {
        let documentsPath = UserFolderUtil.getUserFolder()
        let sourcePath = documentsPath.stringByAppendingPathComponent(filename)
        let destPath = getConfigFilePath(filename: filename.replacingOccurrences(of: "Exported_", with: ""))
        
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destPath)
            return true
        } catch {
            print("Error importing config: \(error)")
            return false
        }
    }
}

// String extension for path manipulation
extension String {
    func stringByAppendingPathComponent(_ component: String) -> String {
        return (self as NSString).appendingPathComponent(component)
    }
}
