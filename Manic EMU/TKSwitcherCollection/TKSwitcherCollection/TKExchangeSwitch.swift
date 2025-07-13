//
//  TKExchangeSwitch.swift
//  SwitcherCollection
//
//  Created by Tbxark on 15/10/25.
//  Copyright © 2015年 TBXark. All rights reserved.
//

import UIKit

// Design by Oleg Frolov
//https://dribbble.com/shots/2238916-Switcher-VI

@IBDesignable
open class TKExchangeSwitch: TKBaseSwitch {

    // MARK: - Property
    open var isSmallStyle: Bool = false {
        didSet {
            resetView()
        }
    }
    open var switchControl: TKExchangeCircleView?
    open var backgroundLayer = CAShapeLayer()

    @IBInspectable open var lineColor = UIColor(white: 0.95, alpha: 1) {
        didSet {
            resetView()
        }
    }

    @IBInspectable open var onColor = UIColor(red: 0.34, green: 0.91, blue: 0.51, alpha: 1.00) {
        didSet {
            resetView()
        }
    }

    @IBInspectable open var offColor = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.00) {
        didSet {
            resetView()
        }
    }

    @IBInspectable open var lineSize: Double = 20 {
        didSet {
            resetView()
        }
    }

    // MARK: - Getter
    open var lineWidth: CGFloat {
        return CGFloat(lineSize) * sizeScale
    }
    
    open var onText: String = "" {
        didSet {
            resetView()
        }
    }
    open var onTextColor: UIColor = .clear {
        didSet {
            resetView()
        }
    }
    open var onTextFont: UIFont = UIFont.systemFont(ofSize: 12) {
        didSet {
            resetView()
        }
    }
    open var offText: String = "" {
        didSet {
            resetView()
        }
    }
    open var offTextColor: UIColor = .clear {
        didSet {
            resetView()
        }
    }
    open var offTextFont: UIFont = UIFont.systemFont(ofSize: 12) {
        didSet {
            resetView()
        }
    }
    private let onLabel = UILabel()
    private let offLabel = UILabel()

    // MARK: - Init

    // MARK: - Private Func
    override internal func setUpView() {
        super.setUpView()

        let radius = self.bounds.height / 2 - lineWidth
        let position = CGPoint(x: radius, y: radius + lineWidth)

        let backLayerPath = UIBezierPath()
        backLayerPath.move(to: CGPoint(x: lineWidth, y: 0))
        backLayerPath.addLine(to: CGPoint(x: bounds.width - 4 * lineWidth, y: 0))

        backgroundLayer.position = position
        backgroundLayer.fillColor = lineColor.cgColor
        backgroundLayer.strokeColor = lineColor.cgColor
        backgroundLayer.lineWidth = self.bounds.height
        backgroundLayer.lineCap = CAShapeLayerLineCap.round
        backgroundLayer.path = backLayerPath.cgPath
        layer.addSublayer(backgroundLayer)

        let switchRadius = bounds.height - lineWidth
        let width = (bounds.width - lineWidth)/2
        let switchControl = TKExchangeCircleView(frame: CGRect(x: lineWidth / 2, y: lineWidth / 2, width: width, height: switchRadius), isSmallStyle: isSmallStyle)
        switchControl.onLayer.fillColor = onColor.cgColor
        switchControl.offLayer.fillColor = offColor.cgColor
        addSubview(switchControl)
        self.switchControl = switchControl
        
        onLabel.center = CGPoint(x: self.bounds.width/4, y: self.bounds.height/2)
        onLabel.text = onText
        onLabel.textColor = onTextColor
        onLabel.font = onTextFont
        onLabel.sizeToFit()
        addSubview(onLabel)
        
        offLabel.center = CGPoint(x: self.bounds.width/4*3, y: self.bounds.height/2)
        offLabel.text = offText
        offLabel.textColor = offTextColor
        offLabel.font = offTextFont
        offLabel.sizeToFit()
        addSubview(offLabel)
    }

    // MARK: - Animate
    override func changeValueAnimate(_ value: Bool, duration: Double) {
        self.on = value
        let keyTimes = [0, 0.4, 0.6, 1]
        guard var frame = self.switchControl?.frame else {
            return
        }
        frame.origin.x = value ? lineWidth / 2 : ((self.bounds.width - lineWidth/2) / 2)

        let switchControlStrokeStartAnim = CAKeyframeAnimation(keyPath: "strokeStart")
        switchControlStrokeStartAnim.values = [0, 0.45, 0.45, 0]
        switchControlStrokeStartAnim.keyTimes = keyTimes as [NSNumber]?
        switchControlStrokeStartAnim.duration = duration
        switchControlStrokeStartAnim.isRemovedOnCompletion = true

        let switchControlStrokeEndAnim = CAKeyframeAnimation(keyPath: "strokeEnd")
        switchControlStrokeEndAnim.values = [1, 0.55, 0.55, 1]
        switchControlStrokeEndAnim.keyTimes = keyTimes as [NSNumber]?
        switchControlStrokeEndAnim.duration = duration
        switchControlStrokeEndAnim.isRemovedOnCompletion = true

        let switchControlChangeStateAnim: CAAnimationGroup = CAAnimationGroup()
        switchControlChangeStateAnim.animations = [switchControlStrokeStartAnim, switchControlStrokeEndAnim]
        switchControlChangeStateAnim.fillMode = CAMediaTimingFillMode.forwards
        switchControlChangeStateAnim.isRemovedOnCompletion = false
        switchControlChangeStateAnim.duration = duration

        backgroundLayer.add(switchControlChangeStateAnim, forKey: "SwitchBackground")
        switchControl?.exchangeAnimate(value, duration: duration)
        
        onLabel.alpha = 0
        offLabel.alpha = 0
        UIView.animate(withDuration: duration, animations: { () -> Void in
            self.switchControl?.frame = frame
            self.onLabel.alpha = 1
            self.offLabel.alpha = 1
            if value {
                self.onLabel.textColor = self.onTextColor
                self.onLabel.font = self.onTextFont
                self.offLabel.textColor = self.offTextColor
                self.offLabel.font = self.offTextFont
            } else {
                self.onLabel.textColor = self.offTextColor
                self.onLabel.font = self.offTextFont
                self.offLabel.textColor = self.onTextColor
                self.offLabel.font = self.onTextFont
            }
        })
    }
}

// MARK: - Deprecated
extension TKExchangeSwitch {
    @available(*, deprecated, message: "color is deprecated. Use lineColor, onColor, offColor instead ")
    var color: (background: UIColor, on: UIColor, off: UIColor) {
        set {
            if newValue.background != lineColor {
                lineColor = newValue.background
            }
            if newValue.on != onColor {
                onColor = newValue.on
            }
            if newValue.on != offColor {
                offColor = newValue.off
            }
        }
        get {
            return (lineColor, onColor, offColor)
        }
    }
}

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        let origin = CGPoint(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0)
        self.init(origin: origin, size: size)
    }
}

open class TKExchangeCircleView: UIView {

    // MARK: - Property
    open var onLayer: CAShapeLayer = CAShapeLayer()
    open var offLayer: CAShapeLayer = CAShapeLayer()
    private var isSmallStyle: Bool

    // MARK: - Init
    init(frame: CGRect, isSmallStyle: Bool = false) {
        self.isSmallStyle = isSmallStyle
        super.init(frame: frame)
        setUpLayer()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private Func
    fileprivate func setUpLayer() {
        let radius = min(self.bounds.width, self.bounds.height)
        let width = self.bounds.width

        let path: UIBezierPath
        if isSmallStyle {
            let newRadius = radius/2
            path = UIBezierPath(ovalIn: CGRect(x: width/2-newRadius/2, y: self.bounds.height/2-newRadius/2, width: newRadius, height: newRadius))
        } else {
            path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: radius), cornerRadius: radius/2)
        }
        
        offLayer.frame = CGRect(x: 0, y: 0, width: width, height: radius)
        offLayer.path = path.cgPath
        offLayer.transform = CATransform3DMakeScale(0, 0, 1)
        self.layer.addSublayer(offLayer)

        onLayer.frame = CGRect(x: 0, y: 0, width: width, height: radius)
        onLayer.path = path.cgPath
        self.layer.addSublayer(onLayer)
    }

    func exchangeAnimate(_ value: Bool, duration: Double) {

        let fillMode = CAMediaTimingFillMode.forwards

        let hideValues = [NSValue(caTransform3D: CATransform3DMakeScale(0, 0, 1)),
                          NSValue(caTransform3D: CATransform3DIdentity)]

        let showValues = [NSValue(caTransform3D: CATransform3DIdentity),
                          NSValue(caTransform3D: CATransform3DMakeScale(0, 0, 1))]

        let showTimingFunction = CAMediaTimingFunction(controlPoints: 0, 0, 0, 1)
        let hideTimingFunction = CAMediaTimingFunction(controlPoints: 0, 0, 1, 1)

        let keyTimes = [0, 1]

        offLayer.zPosition = value ? 1 : 0
        onLayer.zPosition = value ? 0 : 1

        ////OffLayer animation
        let offLayerTransformAnim = CAKeyframeAnimation(keyPath: "transform")
        offLayerTransformAnim.values = value ? hideValues : showValues
        offLayerTransformAnim.keyTimes = keyTimes as [NSNumber]?
        offLayerTransformAnim.duration = duration
        offLayerTransformAnim.timingFunction = value ? hideTimingFunction : showTimingFunction
        offLayerTransformAnim.fillMode = fillMode
        offLayerTransformAnim.isRemovedOnCompletion = false

        ////OnLayer animation
        let onLayerTransformAnim = CAKeyframeAnimation(keyPath: "transform")
        onLayerTransformAnim.values = value ? showValues : hideValues
        onLayerTransformAnim.keyTimes = keyTimes as [NSNumber]?
        onLayerTransformAnim.duration = duration
        offLayerTransformAnim.timingFunction = value ? showTimingFunction : hideTimingFunction
        onLayerTransformAnim.fillMode = fillMode
        onLayerTransformAnim.isRemovedOnCompletion = false

        onLayer.add(onLayerTransformAnim, forKey: "OnAnimate")
        offLayer.add(offLayerTransformAnim, forKey: "OffAnimate")
    }

}
