// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

private let kShowFilesTabKey = "fin.showFilesTab"
private let kShowHomeManagerKey = "fin.showHomeManager"
private let kFullGameIconKey = "fin.fullGameIcon"

/// Config – system, Wii, interface, gameplay, advanced.
struct CoreSettingsView: View {
  @StateObject private var config = ConfigBridge.shared
  @AppStorage(kShowFilesTabKey) private var showFilesTab = true
  @AppStorage(kShowHomeManagerKey) private var showHomeManager = true
  @AppStorage(kFullGameIconKey) private var fullGameIcon = false
  
  var body: some View {
    List {
      // System
      Section {
        SettingRow("Skip IPL (BIOS)", isOn: $config.skipIPL, info: "Skips the GameCube intro and boots straight into the game.")
        
        Picker("GameCube Language", selection: $config.gcLanguage) {
          Text("English").tag(0)
          Text("German").tag(1)
          Text("French").tag(2)
          Text("Spanish").tag(3)
          Text("Italian").tag(4)
          Text("Dutch").tag(5)
        }
        
        Toggle("Allow Region Mismatch", isOn: $config.mismatchedRegionSettings)
      } header: {
        Text("System")
      }
      
      // Wii
      Section {
        Toggle("Progressive Scan", isOn: $config.wiiProgressiveScan)
      } header: {
        Text("Wii")
      }
      
      // Interface
      Section("Interface") {
        Toggle("Show Game Covers", isOn: $config.useGameCovers)
        Toggle("Confirm on Stop", isOn: $config.confirmOnStop)
        SettingRow("Full Icon", isOn: $fullGameIcon, info: "Shows just the cover art on game cards, no title or stats.")
        SettingRow("Pause When in Menu", isOn: $config.pauseWhenInMenu, info: "Pauses the game while the in-game menu is open.")
        Toggle("Skip NKit Warning", isOn: $config.skipNKitWarning)
      }
      
      // Tabs & Menu
      Section("Tabs & Menu") {
        Toggle("Show Files Tab", isOn: $showFilesTab)
        Toggle("Show Home Manager", isOn: $showHomeManager)
      }
      
      // Gameplay
      Section {
        Toggle("Rewind", isOn: $config.rewindEnabled)
        Toggle("Auto Disc Change", isOn: $config.autoDiscChange)
        SettingRow("Fast Disc Speed", isOn: $config.fastDiscSpeed, info: "Cuts down on loading times by reading the disc faster than real hardware.")
      } header: {
        Text("Gameplay")
      }
      
      // Advanced
      Section {
        HStack {
          Picker("Shader Compilation", selection: $config.shaderCompilationMode) {
            Text("Synchronous").tag(0)
            Text("Sync + Uber Shaders").tag(1)
            Text("Async + Uber Shaders").tag(2)
            Text("Async + Skip").tag(3)
          }
          SettingInfoButton(info: "Sync compiles shaders on the spot (can stutter). Async does it in the background (smoother, but you might see missing effects briefly).")
        }
        Toggle("Cheats Enabled", isOn: $config.cheatsEnabled)
        Toggle("Enable Savestates", isOn: $config.enableSavestates)
      } header: {
        Text("Advanced")
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Config")
  }
}

// MARK: - Audio Latency Picker

struct AudioLatencyPickerView: View {
  @StateObject private var config = ConfigBridge.shared
  
  private let latencyOptions = [0, 10, 20, 30, 50, 100, 200]
  
  var body: some View {
    List {
      ForEach(latencyOptions, id: \.self) { latency in
        Button {
          config.audioLatency = latency
        } label: {
          HStack {
            Text("\(latency) ms")
              .foregroundColor(.primary)
            Spacer()
            if config.audioLatency == latency {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Audio Latency")
  }
}

// MARK: - Audio Buffer Size Picker

struct AudioBufferSizePickerView: View {
  @StateObject private var config = ConfigBridge.shared
  
  private let bufferSizes = [32, 64, 100, 128, 150, 256, 512, 1024, 2048]
  
  var body: some View {
    List {
      ForEach(bufferSizes, id: \.self) { size in
        Button {
          config.audioBufferSize = size
        } label: {
          HStack {
            Text("\(size) ms")
              .foregroundColor(.primary)
            Spacer()
            if config.audioBufferSize == size {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Audio Buffer Size")
  }
}

#if DEBUG
struct CoreSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      CoreSettingsView()
    }
  }
}
#endif
