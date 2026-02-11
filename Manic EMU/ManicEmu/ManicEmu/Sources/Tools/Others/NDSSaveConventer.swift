//
//  NDSSaveConventer.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation

struct NDSSaveConventer {
    enum SaveType {
        case unknown, sav, dsv
    }
    
    /// DeSmuME DSV footer的大小（122字节）
    private static let footerSize = 122
    
    /**
     
     footer = [124, 60, 45, 45, 83, 110, 105, 112, 32, 97, 98, 111, 118, 101, 32, 104,
               101, 114, 101, 32, 116, 111, 32, 99, 114, 101, 97, 116, 101, 32, 97, 32,
               114, 97, 119, 32, 115, 97, 118, 32, 98, 121, 32, 101, 120, 99, 108, 117,
               100, 105, 110, 103, 32, 116, 104, 105, 115, 32, 68, 101, 83, 109, 117, 77,
               69, 32, 115, 97, 118, 101, 100, 97, 116, 97, 32, 102, 111, 111, 116, 101,
               114, 58, 1, 0, 0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 1, 0,
               0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 124, 45, 68, 69, 83, 77,
               85, 77, 69, 32, 83, 65, 86, 69, 45, 124]
     */
    
    /// DeSmuME DSV footer标记 "|--Snip above here to create a raw sav by excluding this DeSmuME savedata footer:..." + "|−DESMUME SAVE-|"
    private static let dsvFooter: [UInt8] = [
        124, 60, 45, 45, 83, 110, 105, 112, 32, 97, 98, 111, 118, 101, 32, 104,
        101, 114, 101, 32, 116, 111, 32, 99, 114, 101, 97, 116, 101, 32, 97, 32,
        114, 97, 119, 32, 115, 97, 118, 32, 98, 121, 32, 101, 120, 99, 108, 117,
        100, 105, 110, 103, 32, 116, 104, 105, 115, 32, 68, 101, 83, 109, 117, 77,
        69, 32, 115, 97, 118, 101, 100, 97, 116, 97, 32, 102, 111, 111, 116, 101,
        114, 58, 0, 32, 0, 0, 0, 32, 0, 0, 3, 0, 0, 0, 2, 0,
        0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 124, 45, 68, 69, 83, 77,
        85, 77, 69, 32, 83, 65, 86, 69, 45, 124
    ]
    
    /// DSV footer的起始标记 "|<--Snip"（用于快速检测）
    private static let dsvFooterPrefix: [UInt8] = [124, 60, 45, 45, 83, 110, 105, 112]
    
    /// DSV footer的结束标记 "|-DESMUME SAVE-|"
    private static let dsvFooterSuffix: [UInt8] = [124, 45, 68, 69, 83, 77, 85, 77, 69, 32, 83, 65, 86, 69, 45, 124]
    
    /// sav文件转dsv文件
    @discardableResult
    static func savToDsv(saveUrl: URL) -> Bool {
        guard let saveData = try? Data(contentsOf: saveUrl) else {
            return false
        }
        
        // 创建输出数据：原始sav内容 + footer
        var outputData = saveData
        outputData.append(contentsOf: dsvFooter)
        
        do {
            try outputData.write(to: saveUrl)
            return true
        } catch {
            return false
        }
    }
    
    /// dsv文件转sav文件
    @discardableResult
    static func dsvToSav(saveUrl: URL) -> Bool {
        guard let saveData = try? Data(contentsOf: saveUrl) else {
            return false
        }
        
        // 确保文件足够大，可以包含footer
        guard saveData.count > footerSize else {
            return false
        }
        
        // 去掉末尾的footer
        let trimmedData = saveData.prefix(saveData.count - footerSize)
        
        do {
            try trimmedData.write(to: saveUrl)
            return true
        } catch {
            return false
        }
    }
    
    /// 检查存档文件类型
    /// - Parameter filePath: 文件路径
    /// - Returns: 存档类型（sav、dsv或unknown）
    static func checkSaveType(fileURL: URL) -> SaveType {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            return .unknown
        }
        
        defer {
            try? fileHandle.close()
        }
        
        // 获取文件大小
        guard let fileSize = try? fileHandle.seekToEnd(), fileSize > footerSize else {
            return .unknown
        }
        
        // 读取文件末尾的footer区域来检测
        let suffixLength = UInt64(dsvFooterSuffix.count)
        try? fileHandle.seek(toOffset: fileSize - suffixLength)
        
        guard let suffixData = try? fileHandle.read(upToCount: Int(suffixLength)) else {
            return .unknown
        }
        
        // 检查末尾是否包含 "|-DESMUME SAVE-|" 标记
        if suffixData.elementsEqual(dsvFooterSuffix) {
            return .dsv
        }
        
        // 不是dsv，假设是sav格式
        return .sav
    }
}

