// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import UIKit

@objc class TCView: UIView
{
  var real_view: UIView?
  private var editModeObserver: NSObjectProtocol?
  private var layoutResetObserver: NSObjectProtocol?
  private var editModePanGestures: [UIView: UIPanGestureRecognizer] = [:]
  
  private var _port: Int = 0
  @objc var port: Int
  {
    get { _port }
    set {
      _port = newValue
      guard let view = real_view else { return }
      SetPort(newValue, view: view)
    }
  }

  /// Override in subclasses to provide a unique controller type key (e.g. "gamecube", "wiimote").
  var controllerTypeKey: String {
    return String(describing: type(of: self)).lowercased()
  }
  
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

  private func sharedInit()
  {
    let name = String(describing: type(of: self))
    let bundle = Bundle(for: type(of: self))
    guard let view = bundle.loadNibNamed(name, owner: self, options: nil)?.first as? UIView else {
      return
    }

    view.frame = bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(view)
    real_view = view

    editModeObserver = NotificationCenter.default.addObserver(
      forName: TCLayoutManager.editModeChangedNotification,
      object: nil, queue: .main
    ) { [weak self] _ in
      self?.updateEditMode()
    }

    layoutResetObserver = NotificationCenter.default.addObserver(
      forName: TCLayoutManager.layoutResetNotification,
      object: nil, queue: .main
    ) { [weak self] _ in
      self?.resetAllOffsets()
    }
  }

  deinit {
    if let obs = editModeObserver { NotificationCenter.default.removeObserver(obs) }
    if let obs = layoutResetObserver { NotificationCenter.default.removeObserver(obs) }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Apply saved offsets after Auto Layout finishes
    applyAllSavedOffsets()
  }

  // MARK: - Layout offset support

  /// Returns all draggable control subviews with their layout keys.
  private func draggableControls() -> [(key: String, view: UIView)] {
    guard let container = real_view else { return [] }
    var result: [(String, UIView)] = []
    collectDraggableControls(in: container, into: &result)
    return result
  }

  private func collectDraggableControls(in view: UIView, into result: inout [(String, UIView)]) {
    for subview in view.subviews {
      if let button = subview as? TCButton {
        result.append(("button-\(button.controllerButton)", button))
      } else if let joystick = subview as? TCJoystick {
        result.append(("joystick-\(joystick.joystickType)", joystick))
      } else if let dpad = subview as? TCDirectionalPad {
        result.append(("dpad-\(dpad.directionalPadType)", dpad))
      } else {
        collectDraggableControls(in: subview, into: &result)
      }
    }
  }

  private func applyAllSavedOffsets() {
    let manager = TCLayoutManager.shared
    let ctrlType = controllerTypeKey
    for (key, view) in draggableControls() {
      let offset = manager.loadOffset(forKey: key, controllerType: ctrlType)
      if offset != .zero {
        // Offset is stored as points
        view.transform = CGAffineTransform(translationX: offset.x, y: offset.y)
      }
    }
  }

  private func resetAllOffsets() {
    for (_, view) in draggableControls() {
      UIView.animate(withDuration: 0.25) {
        view.transform = .identity
      }
    }
  }

  // MARK: - Edit mode

  private func updateEditMode() {
    let editing = TCLayoutManager.shared.isEditMode
    let controls = draggableControls()

    if editing {
      for (key, view) in controls {
        guard editModePanGestures[view] == nil else { continue }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleEditPan(_:)))
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)
        editModePanGestures[view] = pan

        // Visual indicator
        view.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        view.layer.borderWidth = 2.0
      }
    } else {
      for (view, pan) in editModePanGestures {
        view.removeGestureRecognizer(pan)
        view.layer.borderWidth = 0
        view.layer.borderColor = nil
      }
      editModePanGestures.removeAll()
    }
  }

  @objc private func handleEditPan(_ gesture: UIPanGestureRecognizer) {
    guard let target = gesture.view else { return }
    let translation = gesture.translation(in: target.superview)

    switch gesture.state {
    case .changed:
      // Accumulate translation on top of existing transform
      let currentTx = target.transform.tx
      let currentTy = target.transform.ty
      target.transform = CGAffineTransform(translationX: currentTx + translation.x, y: currentTy + translation.y)
      gesture.setTranslation(.zero, in: target.superview)

    case .ended, .cancelled:
      // Persist the final offset
      let finalOffset = CGPoint(x: target.transform.tx, y: target.transform.ty)
      if let key = layoutKeyForView(target) {
        TCLayoutManager.shared.saveOffset(finalOffset, forKey: key, controllerType: controllerTypeKey)
      }

    default:
      break
    }
  }

  private func layoutKeyForView(_ view: UIView) -> String? {
    if let button = view as? TCButton {
      return "button-\(button.controllerButton)"
    } else if let joystick = view as? TCJoystick {
      return "joystick-\(joystick.joystickType)"
    } else if let dpad = view as? TCDirectionalPad {
      return "dpad-\(dpad.directionalPadType)"
    }
    return nil
  }

  func SetPort(_ port: Int, view: UIView)
  {
    for subview in view.subviews
    {
      switch subview
      {
      case let button as TCButton:
        button.port = port
      case let joystick as TCJoystick:
        joystick.port = port
      case let dpad as TCDirectionalPad:
        dpad.port = port
      default:
        SetPort(port, view: subview)
      }
    }
  }
  
}
