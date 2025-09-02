//
//  FilterManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

struct FilterManager {
    /// 所有滤镜
    static func allFilters(completion: (([CIFilter])->Void)? = nil) {
        DispatchQueue.global().async {
            var results = [CIFilter]()
            results.append(OriginFilter())
            results.append(CRTFilter())
            enumerateLutFilters { path in
                if let lut = UIImage(contentsOfFile: path), let lutFilter = CICubeColorGenerator(image: lut)?.filter() {
                    lutFilter.name = path.lastPathComponent.deletingPathExtension
                    results.append(lutFilter)
                }
                return false
            }
            DispatchQueue.main.async {
                completion?(results)
            }
        }
    }
    
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
    
    /// 通过名字查找滤镜
    /// - Parameter name: 滤镜名称
    /// - Returns: 滤镜
    static func find(name: String) -> CIFilter? {
        if name == OriginFilter.name {
            return OriginFilter()
        }
        if name == CRTFilter.name {
            return CRTFilter()
        }
        var filter: CIFilter? = nil
        enumerateLutFilters { path in
            if path.lastPathComponent.deletingPathExtension == name {
                if let lut = UIImage(contentsOfFile: path), let lutFilter = CICubeColorGenerator(image: lut)?.filter() {
                    filter = lutFilter
                    return true
                }
            }
            return false
        }
        return filter
    }
    
    
    /// 遍历包内的所有lut滤镜
    /// - Parameter foreach: 遍历中回调每个lut滤镜的地址，如果调用者返回true，则停止遍历
    private static func enumerateLutFilters(foreach: (_ path: String)->Bool) {
        let fileManager = FileManager.default
        let resourcePath = Constants.Path.Resource
        if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
            let lutNames = contents.filter { $0.hasSuffix(".png") }
            for lutName in lutNames {
                if foreach(resourcePath.appendingPathComponent(lutName)) {
                    break
                }
            }
        }
    }
}

struct CICubeColorGenerator {
    
    let image: UIImage
    let dimension: Int
    
    init?(image: UIImage) {
        self.image = image
        
        // check
        let imageWidth = self.image.size.width * self.image.scale
        let imageHeight = self.image.size.height * self.image.scale
        
        dimension = Int(cbrt(Double(imageWidth * imageHeight)))
        
        if Int(imageWidth) % dimension != 0 || Int(imageHeight) % dimension != 0 {
            assertionFailure("invalid image size")
            return nil
        }
        if (dimension * dimension * dimension != Int(imageWidth * imageHeight)) {
            assertionFailure("invalid image size")
            return nil
        }
    }
    
    /// assume all of the 3dLUT image is 8 bit depth in the RGB color space with alpha channel
    func filter() -> CIFilter? {
        
        // get image uncompressed data
        guard let cgImage = image.cgImage else { return nil }
        guard let dataProvider = cgImage.dataProvider else { return nil }
        guard let data = dataProvider.data else { return nil }
        
        guard var pixels = CFDataGetBytePtr(data) else { return nil }
        let length = CFDataGetLength(data)
        let original = pixels
        
        let imageWidth = self.image.size.width * self.image.scale
        let imageHeight = self.image.size.height * self.image.scale
        
        let row = Int(imageHeight) / dimension
        let column = Int(imageWidth) / dimension
        
        // create cube
        var cube = UnsafeMutablePointer<Float>.allocate(capacity: length)
        let origCube = cube
        
        // transform pixels into cube
        for r in 0..<row {
            for c in 0..<column {
                
                /// move to next fragment
                pixels = original
                pixels += Int(imageWidth) * (r * dimension) * 4 + c * dimension * 4
                
                /// read a fragment
                for lr in 0..<dimension {
                    
                    /// move to next line
                    pixels = original
                    let rowStrides = Int(imageWidth) * (r * dimension + lr) * 4
                    let columnStrides = c * dimension * 4
                    pixels += (rowStrides + columnStrides)
                    
                    /// read one line
                    for _ in 0..<dimension {
                        cube.pointee = Float(pixels.pointee) / 255.0; cube += 1; pixels += 1 /// R
                        cube.pointee = Float(pixels.pointee) / 255.0; cube += 1; pixels += 1 /// G
                        cube.pointee = Float(pixels.pointee) / 255.0; cube += 1; pixels += 1 /// B
                        cube.pointee = Float(pixels.pointee) / 255.0; cube += 1; pixels += 1 /// A
                    }
                }
            }
        }
        
        guard let filter = CIFilter(name: "CIColorCube") else { return nil }
        filter.setValue(dimension, forKey: "inputCubeDimension")
        filter.setValue(Data(bytes: origCube, count: length * 4), forKey: "inputCubeData")
        return filter
    }
}
