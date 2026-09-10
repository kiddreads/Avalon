// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import UIKit

/// Manages persisted position offsets for on-screen touch controls.
/// Each control is identified by a string key (e.g. "gamecube-button-0", "gamecube-joystick-10").
/// Offsets are stored as percentages of the container size so they adapt to different screen sizes.
final class TCLayoutManager {
  static let shared = TCLayoutManager()

  /// Posted when edit mode changes. Object is NSNumber(booleanLiteral:).
  static let editModeChangedNotification = Notification.Name("TCLayoutEditModeChanged")
  /// Posted when layout is reset.
  static let layoutResetNotification = Notification.Name("TCLayoutReset")

  private let userDefaultsKey = "DOLTouchControlLayouts"

  private(set) var isEditMode: Bool = false {
    didSet {
      NotificationCenter.default.post(name: Self.editModeChangedNotification, object: NSNumber(value: isEditMode))
    }
  }

  func setEditMode(_ enabled: Bool) {
    isEditMode = enabled
  }

  // MARK: - Offset persistence (stored as % of container)

  /// Save a control's offset as a fraction of the container size.
  func saveOffset(_ offset: CGPoint, forKey key: String, controllerType: String) {
    var all = loadAllOffsets()
    let dictKey = "\(controllerType).\(key)"
    all[dictKey] = ["x": Double(offset.x), "y": Double(offset.y)]
    UserDefaults.standard.set(all, forKey: userDefaultsKey)
  }

  /// Load a control's saved offset (as fraction of container). Returns .zero if none saved.
  func loadOffset(forKey key: String, controllerType: String) -> CGPoint {
    let all = loadAllOffsets()
    let dictKey = "\(controllerType).\(key)"
    guard let dict = all[dictKey] as? [String: Double],
          let x = dict["x"], let y = dict["y"] else {
      return .zero
    }
    return CGPoint(x: x, y: y)
  }

  /// Reset all saved offsets for a specific controller type.
  func resetLayout(forControllerType controllerType: String) {
    var all = loadAllOffsets()
    let prefix = "\(controllerType)."
    for key in all.keys where key.hasPrefix(prefix) {
      all.removeValue(forKey: key)
    }
    UserDefaults.standard.set(all, forKey: userDefaultsKey)
    NotificationCenter.default.post(name: Self.layoutResetNotification, object: nil)
  }

  /// Reset all saved offsets for all controller types.
  func resetAllLayouts() {
    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    NotificationCenter.default.post(name: Self.layoutResetNotification, object: nil)
  }

  private func loadAllOffsets() -> [String: Any] {
    return UserDefaults.standard.dictionary(forKey: userDefaultsKey) ?? [:]
  }
}
