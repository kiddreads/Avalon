//
//  ResourcesKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SSZipArchive
import ZIPFoundation

struct ResourcesKit {
    static func loadResources(completion: ((Bool)->Void)? = nil) {
        //将bunle的加密文件解压到Library中
        
        //新版本更新需要强制刷新资源
        var forceRefresh = false
        if let systemCoreVersion = UserDefaults.standard.string(forKey: Constants.DefaultKey.SystemCoreVersion) {
            let appVersion = Constants.Config.AppVersion
            let appVersionNumber = UInt64(appVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            if systemCoreVersionNumber < appVersionNumber {
                //需要刷新
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Resource))
                forceRefresh = true
            }
        } else {
            //内容为空 则强制刷新
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Resource))
            forceRefresh = true
        }
#if DEBUG
        forceRefresh = true
#endif
        
        if forceRefresh || !FileManager.default.fileExists(atPath: Constants.Path.Resource) {
            //将3DS的文件从Library移到Document 暴露给用户使用
            if FileManager.default.fileExists(atPath: Constants.Path.Library.appendingPathComponent("3DS")),
               !FileManager.default.fileExists(atPath: Constants.Path.ThreeDS) {
                try? FileManager.safeMoveItem(at: URL(fileURLWithPath: Constants.Path.Library.appendingPathComponent("3DS")), to: URL(fileURLWithPath: Constants.Path.ThreeDS))
            }
            //重新将Documents/Datas/3DS/sdmc 转移回 Documents/3DS/sdmc
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc_location.txt")))
            if !FileManager.default.fileExists(atPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc")) {
                if FileManager.default.fileExists(atPath: Constants.Path.Data.appendingPathComponent("3DS/sdmc")) {
                    try? FileManager.safeMoveItem(at: URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("3DS/sdmc")),
                                             to: URL(fileURLWithPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc")),
                                             shouldReplace: true)
                    try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("3DS")))
                } else {
                    try? FileManager.default.createDirectory(atPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc"),
                                                        withIntermediateDirectories: true)
                }
            }
            
            let resourceUrl = Bundle.main.url(forResource: "System", withExtension: "core")!
            Log.debug("开始解压资源:\(Date.now.timeIntervalSince1970ms)")
            SSZipArchive.unzipFile(atPath: resourceUrl.path, toDestination: Constants.Path.Resource, overwrite: true, password: Constants.Cipher.UnzipKey, progressHandler: nil) { _, isSuccess, error in
                
                //处理复用皮肤
                let reuseCores = System.allCores.filter({ $0.gameType.reuseGameType() != $0.gameType })
                for reuse in reuseCores {
                    let templateStandardSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.gameType.reuseGameType().localizedShortName).manicskin")
                    let newStandardSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.name).manicskin")
                    do {
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: templateStandardSkinPath), to: URL(fileURLWithPath: newStandardSkinPath), shouldReplace: true)
                        let archive = try Archive(url: URL(fileURLWithPath: newStandardSkinPath), accessMode: .update)
                        if let oldInfoJson = archive["info.json"] {
                            try archive.remove(oldInfoJson)
                        }
                        try archive.addEntry(with: "info.json", fileURL: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("\(reuse.name).skininfo")))
                    } catch {
                        print("复用皮肤出错:\(error)")
                    }
                    
                    let templateFlexSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.gameType.reuseGameType().localizedShortName)_FLEX.manicskin")
                    let newFlexSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.name)_FLEX.manicskin")
                    do {
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: templateFlexSkinPath), to: URL(fileURLWithPath: newFlexSkinPath), shouldReplace: true)
                        let archive = try Archive(url: URL(fileURLWithPath: newFlexSkinPath), accessMode: .update)
                        if let oldInfoJson = archive["info.json"] {
                            try archive.remove(oldInfoJson)
                        }
                        try archive.addEntry(with: "info.json", fileURL: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("\(reuse.name)_FLEX.skininfo")))
                    } catch {
                        print("复用皮肤出错:\(error)")
                    }
                }
                
                //每次更新资源都删除Libretro的配置
                let libretroConfig = Constants.Path.Libretro.appendingPathComponent("config/retroarch.cfg")
                if FileManager.default.fileExists(atPath: libretroConfig) {
                    try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: libretroConfig))
                }
                
                Log.debug("资源解压结束:\(Date.now.timeIntervalSince1970ms)")
                completion?(isSuccess)
                if isSuccess {
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("aes_keys.txt")), to: URL(fileURLWithPath: Constants.Path.ThreeDSSystemData.appendingPathComponent("aes_keys.txt")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("seeddb.bin")), to: URL(fileURLWithPath: Constants.Path.ThreeDSSystemData.appendingPathComponent("seeddb.bin")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("shared_font.bin")), to: URL(fileURLWithPath: Constants.Path.ThreeDSSystemData.appendingPathComponent("shared_font.bin")), shouldReplace: true)
                    //Libretro的资源复制到对应位置
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/info")), to: URL(fileURLWithPath: Constants.Path.Libretro.appendingPathComponent("info")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/autoconfig")), to: URL(fileURLWithPath: Constants.Path.Libretro.appendingPathComponent("autoconfig")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/shaders")), to: URL(fileURLWithPath: Constants.Path.Libretro.appendingPathComponent("shaders")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/system")), to: URL(fileURLWithPath: Constants.Path.Libretro.appendingPathComponent("system")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.ThreeDSDefaultConfig), to: URL(fileURLWithPath: Constants.Path.ThreeDSConfig), shouldReplace: true)
                    Log.info("资源解压成功!")
                    UserDefaults.standard.set(Constants.Config.AppVersion, forKey: Constants.DefaultKey.SystemCoreVersion)
                } else {
                    if let error = error {
                        Log.error("资源解压失败! error:\(error)")
                    } else {
                        Log.error("资源解压失败!")
                    }
                }
            }
        } else {
            completion?(true)
        }
    }
}
