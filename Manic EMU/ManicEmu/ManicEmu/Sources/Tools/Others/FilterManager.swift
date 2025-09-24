//
//  FilterManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

struct FilterManager {
    static func allLibretroPreviews(origin: UIImage, isGlsl: Bool, completion: (([LibretroPreViewFilter])->Void)? = nil) {
        DispatchQueue.global().async {
            var results = [LibretroPreViewFilter]()
            let originFilter = LibretroPreViewFilter()
            originFilter.name = OriginFilter.name
            results.append(originFilter)
            
            results.append(contentsOf: findLibretroSlangpFiles(in: URL(fileURLWithPath: Constants.Path.Shaders), isGlsl: isGlsl).compactMap({ shader in
                let filter = LibretroPreViewFilter()
                filter.name = shader.deletingPathExtension.lastPathComponent
                filter.shaderPath = shader
                return filter
            }))
            
            DispatchQueue.main.async {
                completion?(results)
            }
        }
    }
    
    static func findLibretroSlangpFiles(in directory: URL, isGlsl: Bool) -> [String] {
        var result: [String] = []

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: isGlsl ? directory.appendingPathComponent("glsl") : directory, includingPropertiesForKeys: nil)
        
        let pathExtension = isGlsl ? "glslp" : "slangp"
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == pathExtension && fileURL.lastPathComponent.deletingPathExtension.lowercased() != "retroarch" {
                result.append(fileURL.path)
            }
        }
        return result.sorted(by: { $0 < $1 })
    }
}
