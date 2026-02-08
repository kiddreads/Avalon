// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import Foundation
import Combine

/// Popup-compatible controllers view. Mapping sheets are presented via a binding to the root.
struct ControllersPopupView: View {
  @Binding var mappingRequest: ControllerMappingRequest?
  @StateObject private var config = ConfigBridge.shared

  @State private var preferredTouch: Bool = true
  @State private var touchControlStyle: TouchControlStyle = TouchControlStyleSetting.current()
  @State private var portsAddedCount: Int = 0
  @State private var gcDeviceNames: [String] = ["", "", "", ""]
  @State private var wiiDeviceNames: [String] = ["", "", "", ""]

  var body: some View {
    List {
      // Input mode
      Section {
        Picker("Player 1 Input", selection: Binding(
          get: { preferredTouch },
          set: { newValue in
            preferredTouch = newValue
            PreferredInput.setPreferredInputTouch(newValue)
            refreshDeviceNames()
          }
        )) {
          Text("Touch").tag(true)
          Text("Controller").tag(false)
        }
        .pickerStyle(.segmented)
      } header: {
        Text("Input")
      }

      // Touch controls
      Section {
        Picker("Style", selection: Binding(
          get: { touchControlStyle },
          set: { newValue in
            touchControlStyle = newValue
            TouchControlStyleSetting.setCurrent(newValue)
          }
        )) {
          ForEach(TouchControlStyle.allCases) { style in
            Text(style.displayName).tag(style)
          }
        }
        .pickerStyle(.segmented)

        VStack(alignment: .leading) {
          HStack {
            Text("Opacity")
            Spacer()
            Text(String(format: "%.0f%%", config.touchPadOpacity * 100))
              .foregroundColor(.secondary)
          }
          Slider(value: $config.touchPadOpacity, in: 0...1)
        }

        Picker("Wii IR Mode", selection: $config.touchPadIRMode) {
          Text("Direct Touch").tag(0)
          Text("Drag Pointer").tag(1)
          Text("Swipe Pointer").tag(2)
        }

        Picker("Mute Switch", selection: $config.muteSwitchMode) {
          Text("Off").tag(0)
          Text("Mute Audio").tag(1)
          Text("Pause").tag(2)
        }

        Button {
          mappingRequest = ControllerMappingRequest(mappingType: .pad, port: 0, forceTouchscreen: true)
        } label: {
          Label("Remap GC Touch", systemImage: "hand.draw.fill")
        }

        Button {
          mappingRequest = ControllerMappingRequest(mappingType: .wiimote, port: 0, forceTouchscreen: true)
        } label: {
          Label("Remap Wii Touch", systemImage: "hand.draw.fill")
        }

        Button(role: .destructive) {
          TCLayoutManager.shared.resetAllLayouts()
        } label: {
          Label("Reset Positions", systemImage: "arrow.counterclockwise")
        }
      } header: {
        Text("Touch Controls")
      }

      // GameCube ports
      Section {
        portRow(label: "Port 1", icon: "gamecontroller.fill",
                device: preferredTouch ? "Touch" : formatDevice(gcDeviceNames, port: 0),
                action: preferredTouch ? nil : { mappingRequest = ControllerMappingRequest(mappingType: .pad, port: 0, forceTouchscreen: false) })
        ForEach(1..<(1 + portsAddedCount), id: \.self) { port in
          portRow(label: "Port \(port + 1)", icon: "gamecontroller.fill",
                  device: formatDevice(gcDeviceNames, port: port),
                  action: { mappingRequest = ControllerMappingRequest(mappingType: .pad, port: port, forceTouchscreen: false) })
        }
        if portsAddedCount < 3 {
          Button {
            portsAddedCount += 1
            PreferredInput.setControllerPortsAddedCount(portsAddedCount)
          } label: {
            Label("Add Port", systemImage: "plus.circle")
          }
        }
      } header: {
        Text("GameCube")
      }

      // Wii remotes
      Section {
        portRow(label: "Remote 1", icon: "rectangle.fill.on.rectangle.fill",
                device: preferredTouch ? "Touch" : formatDevice(wiiDeviceNames, port: 0),
                action: preferredTouch ? nil : { mappingRequest = ControllerMappingRequest(mappingType: .wiimote, port: 0, forceTouchscreen: false) })
        ForEach(1..<(1 + portsAddedCount), id: \.self) { port in
          portRow(label: "Remote \(port + 1)", icon: "rectangle.fill.on.rectangle.fill",
                  device: formatDevice(wiiDeviceNames, port: port),
                  action: { mappingRequest = ControllerMappingRequest(mappingType: .wiimote, port: port, forceTouchscreen: false) })
        }
        if portsAddedCount < 3 {
          Button {
            portsAddedCount += 1
            PreferredInput.setControllerPortsAddedCount(portsAddedCount)
          } label: {
            Label("Add Remote", systemImage: "plus.circle")
          }
        }
      } header: {
        Text("Wii")
      }
    }
    .listStyle(.insetGrouped)
    .onAppear {
      PreferredInput.ensureDefaultPreferredInputIfNeeded()
      PreferredInput.applyPreferredInput()
      preferredTouch = PreferredInput.preferredInputIsTouch()
      touchControlStyle = TouchControlStyleSetting.current()
      portsAddedCount = PreferredInput.controllerPortsAddedCount()
      refreshControllers()
    }
    .onReceive(NotificationCenter.default.publisher(for: .DOLTouchControlStyleChanged)) { _ in
      touchControlStyle = TouchControlStyleSetting.current()
    }
    .onReceive(NotificationCenter.default.publisher(for: .init("ControllersRefreshDevices"))) { _ in
      refreshDeviceNames()
    }
  }

  // MARK: - Port row

  @ViewBuilder
  private func portRow(label: String, icon: String, device: String, action: (() -> Void)?) -> some View {
    if let action {
      Button(action: action) {
        HStack {
          Label(label, systemImage: icon)
          Spacer()
          Text(device)
            .foregroundColor(.secondary)
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(Color(UIColor.quaternaryLabel))
        }
      }
      .buttonStyle(.plain)
    } else {
      HStack {
        Label(label, systemImage: icon)
        Spacer()
        Text(device)
          .foregroundColor(.secondary)
      }
    }
  }

  // MARK: - Helpers

  private func formatDevice(_ names: [String], port: Int) -> String {
    guard names.indices.contains(port), !names[port].isEmpty else { return "Controller" }
    let components = names[port].components(separatedBy: "/")
    if components.count >= 3 {
      let name = components[2].trimmingCharacters(in: .whitespaces)
      return name.isEmpty ? "Touchscreen" : name
    }
    return names[port]
  }

  private func refreshDeviceNames() {
    var gc: [String] = [], wii: [String] = []
    for port in 0..<4 {
      DOLMappingBridge.initialize(for: .pad, port: port)
      gc.append(DOLMappingBridge.defaultDevice() ?? "")
      DOLMappingBridge.initialize(for: .wiimote, port: port)
      wii.append(DOLMappingBridge.defaultDevice() ?? "")
    }
    gcDeviceNames = gc
    wiiDeviceNames = wii
  }

  private func refreshControllers() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { refreshControllers() }
      return
    }
    DOLMappingBridge.refreshDevices()
    refreshDeviceNames()
  }
}

/// Keep old name available for any remaining references
struct ControllersSettingsView: View {
  var body: some View {
    Text("Use Controllers from Settings grid")
  }
}

struct TouchMappingRootView: View {
  let mappingType: MappingType
  let port: Int

  @State private var previousDevice: String = ""
  @State private var ready: Bool = false

  private func touchscreenDeviceString() -> String {
    if mappingType == .pad {
      return "iOS/0/Touchscreen"
    }
    return "iOS/4/Touchscreen"
  }

  private func prepare() {
    DOLMappingBridge.initialize(for: mappingType.dolMappingType, port: port)
    previousDevice = DOLMappingBridge.defaultDevice() ?? ""
    DOLMappingBridge.setDefaultDevice(touchscreenDeviceString())
    DOLMappingBridge.saveConfig()
    ready = true
  }

  private func restore() {
    guard !previousDevice.isEmpty else { return }
    DOLMappingBridge.initialize(for: mappingType.dolMappingType, port: port)
    DOLMappingBridge.setDefaultDevice(previousDevice)
    DOLMappingBridge.saveConfig()
  }

  var body: some View {
    Group {
      if ready {
        MappingRootView(mappingType: mappingType, port: port)
          .onDisappear {
            restore()
          }
      } else {
        Color.clear
          .onAppear {
            prepare()
          }
      }
    }
  }
}

// MARK: - Touchscreen Config View (Opacity, Wii IR Mode, Mute Switch)

struct TouchscreenConfigView: View {
  @StateObject private var config = ConfigBridge.shared
  @State private var touchControlStyle: TouchControlStyle = TouchControlStyleSetting.current()
  
  private var irModeDisplay: String {
    switch config.touchPadIRMode {
    case 0: return "Direct Touch"
    case 1: return "Drag Pointer"
    case 2: return "Swipe Pointer"
    default: return "Unknown"
    }
  }
  
  var body: some View {
    List {
      Section {
        Picker("Touch Controls", selection: Binding(
          get: { touchControlStyle },
          set: { newValue in
            touchControlStyle = newValue
            TouchControlStyleSetting.setCurrent(newValue)
          }
        )) {
          ForEach(TouchControlStyle.allCases) { style in
            Text(style.displayName).tag(style)
          }
        }
        .pickerStyle(.segmented)

        VStack(alignment: .leading) {
          HStack {
            Text("Opacity")
            Spacer()
            Text(String(format: "%.0f%%", config.touchPadOpacity * 100))
              .foregroundColor(.secondary)
          }
          Slider(value: $config.touchPadOpacity, in: 0...1)
        }
      } header: {
        Text("Touchscreen")
      }
      
      Section {
        NavigationLink {
          TouchIRModePickerView()
        } label: {
          HStack {
            Text("Wii IR Mode")
            Spacer()
            Text(irModeDisplay)
              .foregroundColor(.secondary)
          }
        }
      }
      
      Section {
        Picker("Hardware Mute Switch", selection: $config.muteSwitchMode) {
          Text("Off").tag(0)
          Text("Mute Audio").tag(1)
          Text("Pause Emulation").tag(2)
        }
      } header: {
        Text("Hardware Mute Switch")
      } footer: {
        Text("When the device mute switch is on: Off = no change, Mute Audio = mute game sound, Pause Emulation = pause game.")
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Touchscreen")
    .onAppear {
      touchControlStyle = TouchControlStyleSetting.current()
    }
    .onReceive(NotificationCenter.default.publisher(for: .DOLTouchControlStyleChanged)) { _ in
      touchControlStyle = TouchControlStyleSetting.current()
    }
  }
}

// MARK: - Touch IR Mode Picker

struct TouchIRModePickerView: View {
  @StateObject private var config = ConfigBridge.shared
  
  private let modes: [(String, Int)] = [
    ("Direct Touch", 0),
    ("Drag Pointer", 1),
    ("Swipe Pointer", 2),
  ]
  
  var body: some View {
    List {
      Section {
        ForEach(modes, id: \.1) { mode in
          Button {
            config.touchPadIRMode = mode.1
          } label: {
            HStack {
              Text(mode.0)
                .foregroundColor(.primary)
              Spacer()
              if config.touchPadIRMode == mode.1 {
                Image(systemName: "checkmark")
                  .foregroundColor(.accentColor)
              }
            }
          }
        }
      } footer: {
        Text("Controls how touch input maps to the Wii Remote pointer.")
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Wii IR Mode")
  }
}

#if DEBUG
struct ControllersSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ControllersSettingsView()
    }
  }
}
#endif

