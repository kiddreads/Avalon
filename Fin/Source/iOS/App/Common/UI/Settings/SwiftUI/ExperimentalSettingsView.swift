// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Experimental settings tab - advanced/risky options.
struct ExperimentalSettingsView: View {
  @StateObject private var config = ConfigBridge.shared
  @AppStorage("fin.loggingEnabled") private var loggingEnabled = true
  
  var body: some View {
    List {
      // System status (read-only)
      Section {
        HStack {
          Text("User Folder")
          Spacer()
          Text(UserFolderUtil.getUserFolder())
            .foregroundColor(.secondary)
            .font(.caption)
            .lineLimit(1)
        }
      } header: {
        Text("System Status")
      }
      
      // Debugging
      Section {
        Toggle("Panic Handlers", isOn: $config.panicHandlers)
        Toggle("OSD Messages", isOn: $config.osdMessages)
        SettingRow("Pause on Panic", isOn: $config.pauseOnPanic, info: "Freezes the game when an error pops up so you can read it.")
        SettingRow("Abort on Panic Alert", isOn: $config.abortOnPanicAlert, info: "Kills the app on a fatal error instead of trying to keep going.")
      } header: {
        Text("Debugging")
      }
      
      // Logging
      Section {
        SettingRow("Enable Logging", isOn: $loggingEnabled, info: "Turning this off hides console output and can help performance a tiny bit. Restart the app after changing.")
      } header: {
        Text("Logging")
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("EXTRA")
  }
  
}

#if DEBUG
struct ExperimentalSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ExperimentalSettingsView()
    }
  }
}
#endif
