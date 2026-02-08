// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import UIKit

class TCDirectionalPad: UIView
{
  let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

  var dpadNoPressed: UIImage? = nil
  var dpadOnePressed: UIImage? = nil
  var dpadTwoPressed: UIImage? = nil
  
  @IBInspectable var directionalPadType: Int = 6 // default: GC D-Pad
  
  var port: Int = 0
  var isPressed: Bool = false
  private let arrowLabelTag = 9991
  private var isLiquidGlass: Bool = false
  
  override init(frame: CGRect)
  {
    super.init(frame: frame)
  }
  
  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
  }
  
  override func awakeFromNib()
  {
    super.awakeFromNib()
    sharedInit()
  }
  
  func sharedInit()
  {
    // Load image
    dpadNoPressed = getImage(imageName: "gcwii_dpad")
    dpadOnePressed = getImage(imageName: "gcwii_dpad_pressed_one_direction")
    dpadTwoPressed = getImage(imageName: "gcwii_dpad_pressed_two_directions")
    
    // Create the image view
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
    imageView.image = dpadNoPressed
    imageView.center = self.convert(self.center, from: self.superview)
    imageView.isUserInteractionEnabled = true
      
    let pressHandler = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    pressHandler.minimumPressDuration = 0
    imageView.addGestureRecognizer(pressHandler)
    
    self.addSubview(imageView)
    
    // Set background color to transparent
    self.backgroundColor = UIColor.clear

    // Apply glass effect to the container, not the imageView (imageView gets rotated)
    let style = TouchControlStyleSetting.current()
    isLiquidGlass = (style == .liquidGlass)
    self.setLiquidGlassEffectEnabled(isLiquidGlass, cornerRadius: 16)
    if isLiquidGlass {
      // Don't set alpha=0 (blocks touches). Instead clear the images.
      dpadNoPressed = UIImage()
      dpadOnePressed = UIImage()
      dpadTwoPressed = UIImage()
      imageView.image = dpadNoPressed
      addArrowLabels()
    }
  }

  private func addArrowLabels() {
    let arrows = ["↑", "↓", "←", "→"]
    let w = frame.width
    let h = frame.height
    let labelSize: CGFloat = min(w, h) * 0.3
    let positions: [CGPoint] = [
      CGPoint(x: w / 2, y: labelSize * 0.6),           // Up
      CGPoint(x: w / 2, y: h - labelSize * 0.6),       // Down
      CGPoint(x: labelSize * 0.6, y: h / 2),            // Left
      CGPoint(x: w - labelSize * 0.6, y: h / 2),        // Right
    ]
    for (i, arrow) in arrows.enumerated() {
      let label = UILabel(frame: CGRect(x: 0, y: 0, width: labelSize, height: labelSize))
      label.text = arrow
      label.textColor = .white
      label.font = UIFont.systemFont(ofSize: labelSize * 0.6, weight: .medium)
      label.textAlignment = .center
      label.center = positions[i]
      label.isUserInteractionEnabled = false
      label.tag = arrowLabelTag + i
      addSubview(label)
    }
  }
  
  private func highlightArrows(_ presses: [Bool]) {
    // presses: [up, down, left, right] → arrow tags: [up=0, down=1, left=2, right=3]
    for i in 0..<4 {
      if let label = viewWithTag(arrowLabelTag + i) as? UILabel {
        label.textColor = (i < presses.count && presses[i])
          ? UIColor.white
          : UIColor(white: 1.0, alpha: 0.45)
      }
    }
  }

  func getImage(imageName: String) -> UIImage
  {
    // Try Bundle.main first (where xcassets are compiled), then fall back to class bundle
    return UIImage(named: imageName, in: Bundle.main, compatibleWith: nil)
        ?? UIImage(named: imageName, in: Bundle(for: type(of: self)), compatibleWith: nil)
        ?? UIImage(named: imageName)
        ?? UIImage()
  }
  
  @objc func handleLongPress(gesture: UILongPressGestureRecognizer)
  {
    let imageView = gesture.view as! UIImageView
    let point = gesture.location(in: self)
    var buttonPresses: [Bool] = [ false, false, false, false ]
    
    if (gesture.state == .ended)
    {
      imageView.image = dpadNoPressed
      self.isPressed = false
      
      if isLiquidGlass {
        highlightArrows(buttonPresses)
      } else {
        // Liquid animation reset
        UIView.animate(withDuration: 0.2, animations: {
            imageView.transform = .identity
        })
      }
    }
    else
    {
      if (!self.isPressed)
      {
        hapticGenerator.impactOccurred()
        self.isPressed = true
        
        if !isLiquidGlass {
          // Liquid animation press
          UIView.animate(withDuration: 0.1, animations: {
              imageView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
          })
        }
      }
      
      // Get button boundary
      let buttonBounds = gesture.view!.frame.width / 3
      
      // Up
      if (point.y <= buttonBounds)
      {
        buttonPresses[0] = true;
      }
      else if (point.y >= buttonBounds * 2) // Down
      {
        buttonPresses[1] = true;
      }
      
      // Left
      if (point.x <= buttonBounds)
      {
        buttonPresses[2] = true;
      }
      else if (point.x >= buttonBounds * 2) // Right
      {
        buttonPresses[3] = true;
      }
      
      if isLiquidGlass {
        highlightArrows(buttonPresses)
      } else {
        var rotation: CGFloat = 0
        
        // TODO: is there a better way to structure this?
        // Left and Up
        if (buttonPresses[2] && buttonPresses[0])
        {
          imageView.image = dpadTwoPressed
          rotation = 0
        }
        else if (buttonPresses[0] && buttonPresses[3]) // Up and Right
        {
          imageView.image = dpadTwoPressed
          rotation = 90
        }
        else if (buttonPresses[3] && buttonPresses[1]) // Right and Down
        {
          imageView.image = dpadTwoPressed
          rotation = 180
        }
        else if (buttonPresses[1] && buttonPresses[2]) // Down and Left
        {
          imageView.image = dpadTwoPressed
          rotation = 270
        }
        else if (buttonPresses[0]) // Up
        {
          imageView.image = dpadOnePressed
          rotation = 0
        }
        else if (buttonPresses[1]) // Down
        {
          imageView.image = dpadOnePressed
          rotation = 180
        }
        else if (buttonPresses[2]) // Left
        {
          imageView.image = dpadOnePressed
          rotation = 270
        }
        else if (buttonPresses[3]) // Right
        {
          imageView.image = dpadOnePressed
          rotation = 90
        }
        else
        {
          imageView.image = dpadNoPressed
        }
        
        let radians = rotation * (CGFloat.pi / 180)
        imageView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).rotated(by: radians)
      }
    }
    
    // Send button values
    for (i, press) in buttonPresses.enumerated()
    {
      TCManagerInterface.setButtonStateFor(directionalPadType + i, controller: port, state: press)
    }
  }
  
}
