//
//  AuxiliaryLineView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class AuxiliaryLineView: UIView {

    private let crosshairLayer = CAShapeLayer()
    private let dashedBorderLayer = CAShapeLayer()
    
    var enableCrosshair: Bool
    var enableBorder: Bool

    override init(frame: CGRect) {
        self.enableCrosshair = false
        self.enableBorder = false
        super.init(frame: frame)
        setupLayers()
    }
    
    init(frame: CGRect = .zero, enableCrosshair: Bool = false, enableBorder: Bool = false) {
        self.enableCrosshair = enableCrosshair
        self.enableBorder = enableBorder
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        self.enableCrosshair = false
        self.enableBorder = false
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        if enableCrosshair {
            // 十字辅助线样式
            crosshairLayer.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
            crosshairLayer.lineWidth = 2
            crosshairLayer.lineDashPattern = [0, 8] // 0-length + gap = 圆点
            crosshairLayer.lineCap = .round
            layer.addSublayer(crosshairLayer)
        }

        if enableBorder {
            // 虚线边框样式
            dashedBorderLayer.strokeColor = UIColor.white.cgColor
            dashedBorderLayer.fillColor = nil
            dashedBorderLayer.lineWidth = 2
            layer.addSublayer(dashedBorderLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        if enableCrosshair {
            let width = bounds.width
            let height = bounds.height
            let centerX = width / 2
            let centerY = height / 2
            // 十字线路径
            let crossPath = UIBezierPath()
            crossPath.move(to: CGPoint(x: centerX, y: 0))
            crossPath.addLine(to: CGPoint(x: centerX, y: height))
            crossPath.move(to: CGPoint(x: 0, y: centerY))
            crossPath.addLine(to: CGPoint(x: width, y: centerY))
            crosshairLayer.path = crossPath.cgPath
        }

        if enableBorder {
            // 虚线边框路径
            let borderPath = UIBezierPath(rect: bounds)
            dashedBorderLayer.path = borderPath.cgPath
            dashedBorderLayer.frame = bounds
        }
    }
}
