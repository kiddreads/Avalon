// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import UIKit

class TCButton: UIButton
{
  let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    
  @IBInspectable var controllerButton: Int = 0 // default: GC A button
  {
    didSet
    {
      updateImage()
    }
  }
  
  @IBInspectable var isAxis: Bool = false
  
  var port: Int = 0
  var useHapicTouch: Bool = true
  var lastForce: CGFloat = CGFloat.zero
  
  override init(frame: CGRect)
  {
    super.init(frame: frame)
    sharedInit()
  }
  
  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
    sharedInit()
  }
  
  func sharedInit()
  {
    self.setTitle("", for: .normal)
    self.addTarget(self, action: #selector(buttonPressed), for: .touchDown)
    self.addTarget(self, action: #selector(buttonReleased), for: .touchUpInside)
    
    // TODO: Setting for hapic touch analog triggers enabled
    self.useHapicTouch = self.traitCollection.forceTouchCapability == .available

    updateTouchControlStyleIfNeeded()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateTouchControlStyleIfNeeded()
  }

  private let glassLabelTag = 9990

  private func updateTouchControlStyleIfNeeded() {
    let style = TouchControlStyleSetting.current()
    switch style {
    case .standard:
      removeLiquidGlassEffect()
      removeGlassLabel()
      imageView?.isHidden = false
    case .liquidGlass:
      applyLiquidGlassEffect()
      imageView?.isHidden = true
      addOrUpdateGlassLabel()
    }
  }

  private func addOrUpdateGlassLabel() {
    guard let buttonType = TCButtonType(rawValue: controllerButton) else { return }
    let text = buttonType.glassLabel()
    guard !text.isEmpty else { return }

    let label: UILabel
    if let existing = viewWithTag(glassLabelTag) as? UILabel {
      label = existing
    } else {
      label = UILabel()
      label.tag = glassLabelTag
      label.textAlignment = .center
      label.textColor = .white
      label.isUserInteractionEnabled = false
      label.adjustsFontSizeToFitWidth = true
      label.minimumScaleFactor = 0.5
      addSubview(label)
    }

    let fontSize: CGFloat = text.count > 2 ? min(bounds.height * 0.28, 14) : min(bounds.height * 0.38, 22)
    label.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
    label.text = text
    label.frame = bounds
  }

  private func removeGlassLabel() {
    viewWithTag(glassLabelTag)?.removeFromSuperview()
  }
  
  func updateImage()
  {
    let buttonType = TCButtonType(rawValue: controllerButton)!
    
    let buttonImage = getImage(named: buttonType.getImageName(), scale: buttonType.getButtonScale())
    self.setImage(buttonImage, for: .normal)
    
    let buttonPressedImage = getImage(named: buttonType.getImageName() + "_pressed", scale: buttonType.getButtonScale())
    self.setImage(buttonPressedImage, for: .selected)
  }
  
  func getImage(named: String, scale: CGFloat) -> UIImage
  {
    // Try Bundle.main first (where xcassets are compiled), then fall back to class bundle
    guard let image = UIImage(named: named, in: Bundle.main, compatibleWith: nil)
                   ?? UIImage(named: named, in: Bundle(for: type(of: self)), compatibleWith: nil)
                   ?? UIImage(named: named) else {
      // Return a transparent 1x1 fallback to avoid crash
      return UIImage()
    }
    
    // Create a new CGSize with the new scale
    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    
    // Render the image into a context
    UIGraphicsBeginImageContext(newSize)
    image.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
    let newImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    
    return newImage.withRenderingMode(.alwaysOriginal)
  }
  
  @objc func buttonPressed()
  {
    if (isAxis && useHapicTouch)
    {
      return
    }
    
    hapticGenerator.impactOccurred()
    
    // Liquid animation
    UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
        self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        self.alpha = 0.8
    }, completion: nil)
    
    if (isAxis)
    {
      TCManagerInterface.setAxisValueFor(controllerButton, controller: port, value: 1.0)
    }
    else
    {
      TCManagerInterface.setButtonStateFor(controllerButton, controller: port, state: true)
    }
  }
  
  @objc func buttonReleased()
  {
    // Liquid animation reset
    UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 5, options: [.curveEaseInOut, .allowUserInteraction], animations: {
        self.transform = .identity
        self.alpha = 1.0
    }, completion: nil)
    
    if (isAxis)
    {
      TCManagerInterface.setAxisValueFor(controllerButton, controller: port, value: 0.0)
    }
    else
    {
      TCManagerInterface.setButtonStateFor(controllerButton, controller: port, state: false)
    }
  }
  
  @objc override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
  {
    if (!isAxis || !useHapicTouch)
    {
      return
    }
    
    let touch = touches.first!
    let force = touch.force
    let maxForce = touch.maximumPossibleForce
    let percentage: Float = Float(force / maxForce);
    
    TCManagerInterface.setAxisValueFor(controllerButton, controller: port, value: percentage)
    
    if (self.lastForce != force && force == maxForce)
    {
      hapticGenerator.impactOccurred()
    }
    
    self.lastForce = force;
  }
  
}
