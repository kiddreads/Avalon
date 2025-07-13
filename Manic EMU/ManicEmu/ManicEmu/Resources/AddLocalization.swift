#!/usr/bin/swift

import Foundation

// MARK: - 获取当前目录路径
let currentPath = FileManager.default.currentDirectoryPath

// MARK: - 获取输入的 JSON 文件路径
guard CommandLine.arguments.count >= 2 else {
    print("❌ 用法: swift AddLocalization.swift <json文件路径>")
    exit(1)
}

let jsonPath = CommandLine.arguments[1]

// MARK: - 加载并解析 JSON
guard let jsonData = FileManager.default.contents(atPath: jsonPath) else {
    print("❌ 无法读取 JSON 文件: \(jsonPath)")
    exit(1)
}

guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
      let dict = jsonObject as? [String: String] else {
    print("❌ JSON 格式错误，应为 [String: String]")
    exit(1)
}

// MARK: - 遍历字典并写入对应 Localizable.strings
for (lang, value) in dict {
    let localizationPath = "\(currentPath)/\(lang).lproj/Localizable.strings"
    let fileURL = URL(fileURLWithPath: localizationPath)

    // 构建要追加的字符串，带换行
    let newLine = "\n\(value)"

    do {
        // 如果文件不存在则创建
        if !FileManager.default.fileExists(atPath: localizationPath) {
            print("❌ 文件不存在:\(localizationPath)")
        }

        let fileHandle = try FileHandle(forWritingTo: fileURL)
        fileHandle.seekToEndOfFile()
        if let data = newLine.data(using: .utf8) {
            fileHandle.write(data)
        }
        fileHandle.closeFile()
        print("✅ 成功添加至 \(localizationPath)")
    } catch {
        print("⚠️ 写入 \(localizationPath) 失败: \(error.localizedDescription)")
        continue
    }
}