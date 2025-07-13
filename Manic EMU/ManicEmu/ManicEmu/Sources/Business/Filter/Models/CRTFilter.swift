//
//  CRTFilter.swift
//  Filterpedia
//
//  CRT filter and VHS Tracking Lines
//
//  Created by Simon Gladman on 20/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import CoreImage
import CoreImage.CIFilterBuiltins

class CRTFilter: CIFilter {
    static let name = "CRT"
    @objc var inputImage : CIImage?
    let crtWarpFilter = CRTWarpFilter()
    let crtColorFilter = CRTColorFilter()
    let vignette = CIFilter(name: "CIVignette", parameters: [kCIInputIntensityKey: 0.5, kCIInputRadiusKey: 2])!
    
    override init() {
        super.init()
        name = CRTFilter.name
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        
        crtColorFilter.inputImage = inputImage
        vignette.setValue(crtColorFilter.outputImage, forKey: kCIInputImageKey)
        crtWarpFilter.inputImage = vignette.outputImage
        
        // 创建圆角遮罩
        let roundedRectFilter = CIFilter.roundedRectangleGenerator()
        roundedRectFilter.extent = crtWarpFilter.outputImage?.extent ?? inputImage.extent
        roundedRectFilter.radius = 30
        
        let maskImage = roundedRectFilter.outputImage?.cropped(to: inputImage.extent)
        
        return crtWarpFilter.outputImage?.applyingFilter("CIBlendWithMask", parameters: [kCIInputMaskImageKey: maskImage as Any])
    }
    
    class CRTColorFilter: CIFilter {
        @objc var inputImage : CIImage?
        
        var pixelWidth: CGFloat = 1.6
        var pixelHeight: CGFloat = 2
        let crtColorKernel = CIColorKernel(source:
"""
    kernel vec4 crtColor(__sample image, float pixelWidth, float pixelHeight)  {
        vec2 coord = destCoord();
        
        // 添加轻微噪声扰动（减少摩尔纹）
        vec2 noise = vec2(sin(coord.y * 0.02), cos(coord.x * 0.02)) * 0.15;
        coord += noise;
        
        int columnIndex = int(mod(coord.x / pixelWidth, 3.0));
        int rowIndex = int(mod(coord.y, pixelHeight));
        
        float scanlineMultiplier = 0.85 + 0.15 * sin(coord.y * 3.14159 / pixelHeight);
        
        // **颜色通道增强**
        float red = (columnIndex == 0) ? image.r * 1.1 : image.r * ((columnIndex == 2) ? 0.95 : 0.85);
        float green = (columnIndex == 1) ? image.g * 1.1 : image.g * ((columnIndex == 2) ? 0.92 : 0.85);
        float blue = (columnIndex == 2) ? image.b * 1.15 : image.b * 0.82;
        
        // **增加色彩失真**
        red += 0.02 * sin(coord.y * 0.05);
        blue += 0.02 * cos(coord.x * 0.05);
        
        // 计算像素点的柔和边缘
        float pixelBlend = smoothstep(0.3, 0.7, fract(coord.x / pixelWidth));
        
        // 颜色插值，避免边缘过硬
        red   = mix(image.r, red, pixelBlend);
        green = mix(image.g, green, pixelBlend);
        blue  = mix(image.b, blue, pixelBlend);
        
        // **增加对比度**
        vec3 color = vec3(red, green, blue) * scanlineMultiplier;
        color = mix(vec3(0.0), color, 1.2);   // 提高对比度
        
        return vec4(color, 0.75);  // Alpha 设置成 0.75 模拟 CRT 玻璃反射
    }
""")
        
        
        override var outputImage: CIImage? {
            if let inputImage = inputImage, let crtColorKernel = crtColorKernel {
                let dod = inputImage.extent
                let args = [inputImage, pixelWidth, pixelHeight] as [Any]
                return crtColorKernel.apply(extent: dod, arguments: args)
            }
            return nil
        }
    }
    
    class CRTWarpFilter: CIFilter  {
        @objc var inputImage : CIImage?
        var bend: CGFloat = 5.0
        
        let crtWarpKernel = CIWarpKernel(source:
            "kernel vec2 crtWarp(vec2 extent, float bend)" +
                "{" +
                "   vec2 coord = ((destCoord() / extent) - 0.5) * 2.0;" +
                
                "   coord.x *= 1.0 + pow((abs(coord.y) / bend), 2.0);" +
                "   coord.y *= 1.0 + pow((abs(coord.x) / bend), 2.0);" +
                
                "   coord  = ((coord / 2.0) + 0.5) * extent;" +
                
                "   return coord;" +
            "}"
        )
        
        override var outputImage : CIImage? {
            if let inputImage = inputImage,
               let crtWarpKernel = crtWarpKernel {
                let arguments = [CIVector(x: inputImage.extent.size.width, y: inputImage.extent.size.height), bend] as [Any]
                let extent = inputImage.extent.insetBy(dx: -1, dy: -1)
                return crtWarpKernel.apply(extent: extent, roiCallback: {
                    (index, rect) in
                    return rect
                }, image: inputImage, arguments: arguments)
            }
            return nil
        }
    }
    
}

