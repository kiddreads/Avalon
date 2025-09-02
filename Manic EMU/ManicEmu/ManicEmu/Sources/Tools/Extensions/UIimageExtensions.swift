//
//  UIimageExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/9.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import DominantColors

extension UIImage {
    
    static func symbolImage(_ symbol: SFSymbol) -> UIImage {
        UIImage(symbol: symbol)
    }

    /// 生成SFSymbol
    /// - Parameters:
    ///   - symbol: symbol
    ///   - size: 尺寸 默认:Constants.Size.SymbolSize
    ///   - weight: 字重 默认:regular
    ///   - font: 字体大小，如果设置了font，则size、weight无效 默认:nil
    ///   - color: 颜色 默认:Constants.Color.LabelPrimary
    ///   - colors: 调色盘 如果设置了colors，则color无效 默认:nil
    convenience init(symbol: SFSymbol,
                     size: CGFloat = Constants.Size.SymbolSize,
                     weight: UIFont.Weight = .regular,
                     font: UIFont? = nil,
                     color: UIColor = Constants.Color.LabelPrimary,
                     colors: [UIColor]? = nil) {
        let sizeConfig = UIImage.SymbolConfiguration(font: font ?? UIFont.systemFont(ofSize: size))
        let colorConfig = UIImage.SymbolConfiguration(paletteColors: colors ?? [color])
        self.init(systemSymbol: symbol, withConfiguration: sizeConfig.applying(colorConfig))
    }
    
    
    /// 生成一个可以设定背景大小的SFSymbol
    /// - Parameters:
    ///   - backgroundColor: 背景颜色
    ///   - imageSize: 整个图片大小
    convenience init(symbol: SFSymbol,
                     size: CGFloat = Constants.Size.SymbolSize,
                     weight: UIFont.Weight = .regular,
                     font: UIFont? = nil,
                     color: UIColor = Constants.Color.LabelPrimary,
                     colors: [UIColor]? = nil,
                     backgroundColor: UIColor,
                     imageSize: CGSize) {
        let symbolImage = UIImage(symbol: symbol, size: size, weight: weight, font: font, color: color, colors: colors)
        let format = UIGraphicsImageRendererFormat()
        guard let image = UIGraphicsImageRenderer(size: imageSize, format: format).image(actions: { context in
            backgroundColor.setFill()
            context.fill(context.format.bounds)
            symbolImage.draw(in: CGRect(center: CGPoint(x: imageSize.width/2, y: imageSize.height/2), size: CGSize(width: size, height: size)))
        }).cgImage else {
            self.init()
            return
        }
        self.init(cgImage: image, scale: UIWindow.applicationWindow?.screen.scale ?? 1, orientation: .up)
    }
    
    /// 自定义SFSymbol配置
    /// - Parameters:
    ///   - symbol: symbol
    ///   - size: 尺寸 默认:Constants.Size.SymbolSize
    ///   - weight: 字重 默认:regular
    ///   - font: 字体大小，如果设置了font，则size、weight无效 默认:nil
    ///   - color: 颜色 默认:Constants.Color.LabelPrimary
    ///   - colors: 调色盘 如果设置了colors，则color无效 默认:nil
    func applySymbolConfig(size: CGFloat = Constants.Size.SymbolSize,
                           weight: UIFont.Weight = .regular,
                           font: UIFont? = nil,
                           color: UIColor = Constants.Color.LabelPrimary,
                           colors: [UIColor]? = nil) -> UIImage {
        let sizeConfig = UIImage.SymbolConfiguration(font: font ?? UIFont.systemFont(ofSize: Constants.Size.SymbolSize))
        let colorConfig = UIImage.SymbolConfiguration(paletteColors: colors ?? [color])
        return self.withConfiguration(sizeConfig.applying(colorConfig))
    }
    
    /// 获取缺省图
    /// - Parameter preferenceSize: 调整大小
    /// - Returns: 图片
    static func placeHolder(preferenceSize: CGSize? = nil) -> UIImage {
        let image = R.image.place_holder()!
        if let preferenceSize = preferenceSize {
            return image.scaled(toSize: preferenceSize) ?? image
        }
        return image
    }
    
    /// 根据尺寸缩放图片 如果传入的尺寸比例和原图不一致还会进行居中裁剪
    func scaled(toSize: CGSize, opaque: Bool = false) -> UIImage? {
        guard toSize != .zero else { return self }
        
        var toSize = toSize
        if let scene = ApplicationSceneDelegate.applicationScene, self.scale != scene.screen.scale {
            //scale不同需要对size做一些处理
            let ratio = scene.screen.scale/self.scale
            toSize = CGSize(width: toSize.width * ratio, height: toSize.height * ratio)
        }
        
        var isMaxHeight: Bool = false
        var isSideEqual: Bool = false
        let scaledImage: UIImage?
        if toSize.width >= toSize.height {
            scaledImage = scaled(toHeight: toSize.height, opaque: opaque)
            isSideEqual = true
        }else {
            scaledImage = scaled(toWidth: toSize.width, opaque: opaque)
            isMaxHeight = true
        }
        
        guard let scaledImage = scaledImage else { return self }
        
        if isSideEqual {
            return scaledImage
        } else {
            let croppedRect = CGRect(center: isMaxHeight ? .init(x: scaledImage.size.width/2, y: 0) : .init(x: 0, y: scaledImage.size.height/2), size: toSize)
            return scaledImage.cropped(to: croppedRect)
        }
    }
    
    ///尝试将data转换成图片 如果失败则返回缺省图
    static func tryDataImageOrPlaceholder(tryData: Data?, preferenceSize: CGSize? = nil) -> UIImage {
        if let tryData = tryData, let image = UIImage(data: tryData, scale: ApplicationSceneDelegate.applicationScene?.screen.scale ?? 1) {
            if let preferenceSize = preferenceSize {
                return image.scaled(toSize: preferenceSize) ?? image
            }
            return image
        } else {
            return UIImage.placeHolder(preferenceSize: preferenceSize)
        }
    }
    
    /// 为image生成主背景
    var dominantBackground: UIColor {
        return dominantColors().background ?? Constants.Color.BackgroundPrimary
    }
    
    func dominantColors() -> (background: UIColor?, primary: UIColor?, secondary: UIColor?) {
        if let cgImage = self.cgImage,
            let colors = try? DominantColors.dominantColors(image: cgImage, options: [.excludeGray]),
            let contrastColors = ContrastColors(orderedColors: colors, ignoreContrastRatio: true) {
            return (contrastColors.background.uiColor, contrastColors.primary.uiColor, contrastColors.secondary?.uiColor)
        }
        return (nil, nil, nil)
    }
    
    func processGameSnapshop() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let imageScale = Constants.Numbers.GameSnapshotScaleRatio
        let imageSize = CGSize(width: self.size.width * imageScale, height: self.size.height * imageScale)
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        let screenshotData = renderer.pngData { (context) in
            context.cgContext.interpolationQuality = .none
            self.draw(in: CGRect(origin: .zero, size: imageSize))
        }
        return screenshotData
    }
    
    func applyFilter(filter: CIFilter) -> UIImage? {
        if filter is OriginFilter {
            return self
        }
        guard let ciImage = CIImage(image: self) else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let outputCIImage = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else { return nil }
        let filteredImage = UIImage(cgImage: cgImage)
        return filteredImage
    }
}
