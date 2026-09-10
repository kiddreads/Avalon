// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import UIKit

/// User preference for core fast math (saved; actual fast math is set at build time).
private let kPreferFastMathKey = "DOLPreferFastMathCore"

/// Per-game override: use safe (non–fast-math) core for these game IDs when we support two cores.
enum SafeCoreGameIDsStorage {
  static let key = "DOLSafeCoreGameIDs"
  static func add(_ gameId: String) {
    guard !gameId.isEmpty else { return }
    var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
    if !ids.contains(gameId) { ids.append(gameId); UserDefaults.standard.set(ids, forKey: key) }
  }
  static func remove(_ gameId: String) {
    var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
    ids.removeAll { $0 == gameId }
    UserDefaults.standard.set(ids, forKey: key)
  }
  static func contains(_ gameId: String) -> Bool {
    (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(gameId)
  }
  static func all() -> [String] {
    UserDefaults.standard.stringArray(forKey: key) ?? []
  }
}

/// CPU – core engine, threading, speed, overclock.
struct CPUSettingsView: View {
  @StateObject private var config = ConfigBridge.shared
  @AppStorage(kPreferFastMathKey) private var preferFastMath = false
  @State private var safeCoreGameIds: [String] = []

  var body: some View {
    List {
      // CPU
      Section {
        Picker("CPU Core", selection: $config.cpuCore) {
          Text("Interpreter").tag(0)
          Text("Cached Interpreter").tag(1)
          Text("Inline Cached Interpreter").tag(2)
        }
        if config.cpuCore == 1 || config.cpuCore == 2 {
          NavigationLink {
            InterpreterCachePickerView()
          } label: {
            HStack {
              Text("Code Cache Size")
              Spacer()
              Text("\(config.interpreterCacheSize) MB")
                .foregroundColor(.secondary)
            }
          }
        }
        SettingRow("Dual Core", isOn: $config.dualCore, info: "Runs the CPU and GPU on separate threads. Faster, but a few games don't like it.")
        Toggle("Idle Skip", isOn: $config.idleSkip)
        Toggle("Precision Frame Timing", isOn: $config.precisionFrameTiming)
        SettingRow("MMU", isOn: $config.mmu, info: "Full memory management. Needed by a handful of games, but slower.")
        SettingRow("Sync GPU", isOn: $config.syncGPU, info: "Keeps the GPU in lockstep with the CPU. More accurate timing, but costs speed.")
        SettingRow("Fastmem", isOn: $config.fastmem, info: "Speeds up memory access. Safe to leave on for most games.")
      } header: {
        Text("CPU")
      }

      // Emulation Speed
      Section {
        NavigationLink {
          EmulationSpeedPickerView()
        } label: {
          HStack {
            Text("Speed Limit")
            Spacer()
            Text(config.emulationSpeedDisplay)
              .foregroundColor(.secondary)
          }
        }
      } header: {
        Text("Emulation Speed")
      }

      // Anti-Aliasing
      Section {
        NavigationLink {
          MSAAPickerView()
        } label: {
          HStack {
            Text("Anti-Aliasing")
            Spacer()
            Text(msaaDisplay)
              .foregroundColor(.secondary)
          }
        }
      } header: {
        Text("Anti-Aliasing")
      }

      // Overclock
      Section {
        Toggle("Enable Overclock", isOn: $config.overclockEnable)
        if config.overclockEnable {
          HStack {
            Text("Clock Speed")
            Slider(value: $config.overclock, in: 0.1...4.0, step: 0.1)
            Text("\(Int(config.overclock * 100))%")
              .frame(width: 50)
          }
        }
      } header: {
        Text("Overclock")
      }

      // VI Overclock
      Section {
        Toggle("Enable VI Overclock", isOn: $config.viOverclockEnable)
        if config.viOverclockEnable {
          HStack {
            Text("VI Rate")
            Slider(value: $config.viOverclock, in: 0.1...2.0, step: 0.01)
            Text(String(format: "%.0f%%", config.viOverclock * 100))
              .frame(width: 44)
          }
        }
      } header: {
        Text("VI Overclock")
      }

      // Core: fast math
      Section {
        Toggle("Prefer fast math (core)", isOn: $preferFastMath)
        HStack {
          Text("This build")
          Spacer()
          Text(fastMathCoreDisplay)
            .foregroundColor(.secondary)
        }
        if !safeCoreGameIds.isEmpty {
          ForEach(safeCoreGameIds, id: \.self) { gameId in
            HStack {
              Text(gameId)
                .font(.system(.body, design: .monospaced))
              Spacer()
              Button("Remove") {
                SafeCoreGameIDsStorage.remove(gameId)
                safeCoreGameIds = SafeCoreGameIDsStorage.all()
              }
              .font(.caption)
            }
          }
        }
      } header: {
        Text("Core build")
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("CPU")
    .onAppear { safeCoreGameIds = SafeCoreGameIDsStorage.all() }
  }

  private var fastMathCoreDisplay: String {
    #if FAST_MATH_CORE_BUILD
    return "On"
    #else
    return "Off"
    #endif
  }

  private var msaaDisplay: String {
    MSAAOptions.label(for: config.msaa)
  }
}

// MARK: - MSAA Picker

struct MSAAPickerView: View {
  @StateObject private var config = ConfigBridge.shared

  var body: some View {
    List {
      ForEach(MSAAOptions.all, id: \.1) { option in
        Button {
          config.msaa = option.1
        } label: {
          HStack {
            Text(option.0)
              .foregroundColor(.primary)
            Spacer()
            if config.msaa == option.1 {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Anti-Aliasing")
  }
}

// MARK: - Emulation Speed Picker

struct EmulationSpeedPickerView: View {
  @StateObject private var config = ConfigBridge.shared

  private let speedOptions: [(String, Float)] = [
    ("Unlimited", 0),
    ("25%", 0.25),
    ("50%", 0.5),
    ("75%", 0.75),
    ("100%", 1.0),
    ("125%", 1.25),
    ("150%", 1.5),
    ("200%", 2.0),
  ]

  var body: some View {
    List {
      ForEach(speedOptions, id: \.1) { option in
        Button {
          config.emulationSpeed = option.1
        } label: {
          HStack {
            Text(option.0)
              .foregroundColor(.primary)
            Spacer()
            if config.emulationSpeed == option.1 {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Speed Limit")
  }
}

// MARK: - Interpreter Cache Picker

struct InterpreterCachePickerView: View {
  @StateObject private var config = ConfigBridge.shared

  private let cacheSizes = [32, 48, 64, 96, 128, 192, 256, 384, 512]

  var body: some View {
    List {
      ForEach(cacheSizes, id: \.self) { size in
        Button {
          config.interpreterCacheSize = size
        } label: {
          HStack {
            Text("\(size) MB")
              .foregroundColor(.primary)
            Spacer()
            if config.interpreterCacheSize == size {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Code Cache Size")
  }
}

#if DEBUG
  struct CPUSettingsView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        CPUSettingsView()
      }
    }
  }
#endif
