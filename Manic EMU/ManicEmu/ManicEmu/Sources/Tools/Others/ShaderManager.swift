//
//  ShaderManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

struct ShaderManager {
    
    static func fetchShaders(source: ShadersListView.ShaderSource? = nil, isGlsl: Bool, selectedShader: Shader?, includeOriginal: Bool) -> ShadersListData {
        var result = ShadersListData()
        let sourceCase = source == nil ? ShadersListView.ShaderSource.allCases : [source!]
        for source in sourceCase {
            if source == .imported {
                if FileManager.default.fileExists(atPath: Constants.Path.ShaderImportedInDocument) {
                    //复制到shader的工作区
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.ShaderImportedInDocument), to: URL(fileURLWithPath: Constants.Path.ShaderImported), shouldReplace: true)
                } else {
                    try? FileManager.default.createDirectory(atPath: Constants.Path.ShaderImportedInDocument, withIntermediateDirectories: true)
                }
            }
            let isRecursive = source != .custom
            let shadersRelativePathes = findShaderFiles(in: source.searchUrl, isGlsl: isGlsl, isRecursive: isRecursive)
            switch source {
            case .default, .custom:
                var shaders = shadersRelativePathes.map({ genShader($0, isSelected: selectedShader == nil ? false : ($0 == selectedShader!.relativePath)) })
                if source == .default, includeOriginal {
                    shaders.insert(ShaderManager.genOriginalShader(isSelected: selectedShader == nil ? true : false), at: 0)
                }
                result[source] = [("", shaders)]
            case .retroarch, .imported:
                var subResult = [String: [Shader]]()
                for path in shadersRelativePathes {
                    let sectionTitleIndex = source == .retroarch ? 2 : 1
                    let components = path.pathComponents
                    if components.count > sectionTitleIndex + 1 {
                        let sectionTitle = components[sectionTitleIndex]
                        let shader = genShader(path, isSelected: selectedShader == nil ? false : (path == selectedShader!.relativePath))
                        if var shaderArray = subResult[sectionTitle] {
                            shaderArray.append(shader)
                            subResult[sectionTitle] = shaderArray.sorted(by: {
                                $0.title.lowercased() < $1.title.lowercased()
                            })
                        } else {
                            subResult[sectionTitle] = [shader]
                        }
                    }
                }
                result[source] = subResult.sorted(by: \.key).map({ ($0, $1) })
            }
        }
        return result
    }
    
    private static func findShaderFiles(in directory: URL, isGlsl: Bool, isRecursive: Bool) -> [String] {
        var result: [String] = []
        let fileManager = FileManager.default
        let pathExtension = isGlsl ? "glslp" : "slangp"
        if isRecursive {
            let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == pathExtension && fileURL.lastPathComponent.deletingPathExtension.lowercased() != "retroarch",
                    let relativePath = getRelativePath(fileURL.path) {
                    result.append(relativePath)
                }
            }
        } else {
            if let fileUrls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
                for fileUrl in fileUrls {
                    let isDirectory = (try? fileUrl.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if !isDirectory,
                       fileUrl.pathExtension.lowercased() == pathExtension,
                       fileUrl.lastPathComponent.deletingPathExtension.lowercased() != "retroarch",
                       let relativePath = getRelativePath(fileUrl.path) {
                        result.append(relativePath)
                    }
                }
            }
        }
        return result.sorted(by: { $0 < $1 })
    }
    
    private static func getRelativePath(_ path: String) -> String? {
        if let range = path.range(of: "/Libretro/shaders/") {
            return String(path[range.upperBound...])
        }
        return nil
    }
    
    static func genShader(_ relativePath: String, isSelected: Bool) -> Shader {
        Shader(title: relativePath.deletingPathExtension.lastPathComponent, isSelected: isSelected, relativePath: relativePath)
    }
    
    static func genOriginalShader(isSelected: Bool) -> Shader {
        var shader = Shader(title: R.string.localizable.filterOriginTitle(), isSelected: isSelected, relativePath: "")
        shader.isOriginal = true
        return shader
    }
    
}
