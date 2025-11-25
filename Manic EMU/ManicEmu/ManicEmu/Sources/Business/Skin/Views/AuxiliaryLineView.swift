//
//  AuxiliaryLineView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class AuxiliaryLineView: UIView {

    private let crosshairLayer = CAShapeLayer()
    private let dashedBorderLayer = CAShapeLayer()
    
    var enableCrosshair: Bool
    var enableBorder: Bool
    
    // 边缘拖动手柄
    let topHandle: UIView = {
        let view = UIView()
        let icon = IconView()
        icon.imageView.contentMode = .scaleAspectFill
        icon.image = UIImage(symbol: .chevronCompactUp, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        view.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 40, height: 20))
        }
        return view
    }()
    let bottomHandle: UIView = {
        let view = UIView()
        let icon = IconView()
        icon.imageView.contentMode = .scaleAspectFill
        icon.image = UIImage(symbol: .chevronCompactDown, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        view.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 40, height: 20))
        }
        return view
    }()
    let leftHandle: UIView = {
        let view = UIView()
        let icon = IconView()
        icon.imageView.contentMode = .scaleAspectFill
        icon.image = UIImage(symbol: .chevronCompactLeft, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        view.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 20, height: 40))
        }
        return view
    }()
    let rightHandle: UIView = {
        let view = UIView()
        let icon = IconView()
        icon.imageView.contentMode = .scaleAspectFill
        icon.image = UIImage(symbol: .chevronCompactRight, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        view.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 20, height: 40))
        }
        return view
    }()

    override init(frame: CGRect) {
        self.enableCrosshair = false
        self.enableBorder = false
        super.init(frame: frame)
        setupLayers()
        setupEdgeHandles()
    }
    
    init(frame: CGRect = .zero, enableCrosshair: Bool = false, enableBorder: Bool = false) {
        self.enableCrosshair = enableCrosshair
        self.enableBorder = enableBorder
        super.init(frame: frame)
        setupLayers()
        setupEdgeHandles()
    }

    required init?(coder: NSCoder) {
        self.enableCrosshair = false
        self.enableBorder = false
        super.init(coder: coder)
        setupLayers()
        setupEdgeHandles()
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
            dashedBorderLayer.lineWidth = 1
            layer.addSublayer(dashedBorderLayer)
        }
    }
    
    private func setupEdgeHandles() {
        guard enableBorder else { return }
        
        addSubview(topHandle)
        topHandle.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(20)
        }
        
        addSubview(bottomHandle)
        bottomHandle.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(20)
        }
        
        addSubview(leftHandle)
        leftHandle.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(20)
        }
        
        addSubview(rightHandle)
        rightHandle.snp.makeConstraints { make in
            make.right.top.bottom.equalToSuperview()
            make.width.equalTo(20)
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
