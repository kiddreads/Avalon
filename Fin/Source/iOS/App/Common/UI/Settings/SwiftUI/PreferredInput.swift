// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// Persisted preference: Use Touch vs Use Controller for port 0.
/// Default: Touch if no physical controller detected, Controller if one is connected.
/// Always respect and persist the user's manual selection.
enum PreferredInput {
  private static let preferredKey = "DOLPreferredInputTouch"
  private static let portsAddedKey = "DOLControllerPortsAdded"

  /// Whether the user prefers touch (true) or physical controller (false) for port 0.
  /// On first read when key is unset, runs default detection and persists.
  static func preferredInputIsTouch() -> Bool {
    ensureDefaultPreferredInputIfNeeded()
    return UserDefaults.standard.bool(forKey: preferredKey)
  }

  /// Set preferred input and apply to port 0 for both Pad and Wiimote.
  static func setPreferredInputTouch(_ useTouch: Bool) {
    UserDefaults.standard.set(useTouch, forKey: preferredKey)
    applyPreferredInput()
  }

  /// Touchscreen device string for port 0 (matches DOLMappingBridge: Pad = iOS/0/Touchscreen, Wii = iOS/4/Touchscreen).
  private static func touchscreenDeviceString(for type: DOLMappingType) -> String {
    type == .pad ? "iOS/0/Touchscreen" : "iOS/4/Touchscreen"
  }

  /// Apply current preferred input to port 0: set default device to touchscreen or first physical controller.
  static func applyPreferredInput() {
    let useTouch = UserDefaults.standard.bool(forKey: preferredKey)

    // Pad port 0
    DOLMappingBridge.initialize(for: .pad, port: 0)
    if useTouch {
      DOLMappingBridge.setDefaultDevice(touchscreenDeviceString(for: .pad))
    } else {
      let devices = DOLMappingBridge.devices(with: .physicalOnly)
      if let first = devices.first(where: { !$0.isDisconnected }) {
        DOLMappingBridge.setDefaultDevice(first.name)
      }
    }
    DOLMappingBridge.saveConfig()

    // Wiimote port 0
    DOLMappingBridge.initialize(for: .wiimote, port: 0)
    if useTouch {
      DOLMappingBridge.setDefaultDevice(touchscreenDeviceString(for: .wiimote))
    } else {
      let devices = DOLMappingBridge.devices(with: .physicalOnly)
      if let first = devices.first(where: { !$0.isDisconnected }) {
        DOLMappingBridge.setDefaultDevice(first.name)
      }
    }
    DOLMappingBridge.saveConfig()
  }

  /// If preference has never been set, detect (no controller → Touch, else Controller), persist, and apply.
  static func ensureDefaultPreferredInputIfNeeded() {
    if UserDefaults.standard.object(forKey: preferredKey) != nil {
      return
    }
    DOLMappingBridge.initialize(for: .pad, port: 0)
    let physical = DOLMappingBridge.devices(with: .physicalOnly)
    let useTouch = physical.isEmpty || physical.allSatisfy { $0.isDisconnected }
    UserDefaults.standard.set(useTouch, forKey: preferredKey)
    applyPreferredInput()
  }

  /// Re-check: if no physical controller is connected, auto-switch to touch.
  /// Call this on emulation start or when controllers change.
  static func autoSwitchToTouchIfNoController() {
    DOLMappingBridge.initialize(for: .pad, port: 0)
    let physical = DOLMappingBridge.devices(with: .physicalOnly)
    let noController = physical.isEmpty || physical.allSatisfy { $0.isDisconnected }
    if noController && !preferredInputIsTouch() {
      setPreferredInputTouch(true)
    }
  }

  /// Number of extra controller ports shown (0 = only Port 1; 1 = Port 1+2; … 3 = all four).
  static func controllerPortsAddedCount() -> Int {
    let n = UserDefaults.standard.integer(forKey: portsAddedKey)
    return min(max(n, 0), 3)
  }

  static func setControllerPortsAddedCount(_ count: Int) {
    UserDefaults.standard.set(min(max(count, 0), 3), forKey: portsAddedKey)
  }
}
