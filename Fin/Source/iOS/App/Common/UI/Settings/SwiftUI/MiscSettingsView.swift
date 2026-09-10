// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

// MiscSettingsView has been merged into CoreSettingsView (Config).
// This file is kept for the AudioBackendPickerView used by AudioSettingsView.

// MARK: - Audio Backend Picker

struct AudioBackendPickerView: View {
  @StateObject private var config = ConfigBridge.shared
  
  var body: some View {
    List {
      // Get backends dynamically from core
      ForEach(getAvailableBackends(), id: \.self) { backend in
        Button {
          config.audioBackend = backend
          // When switching away from Bell, disable Bell features
          if backend != "Bell" {
            config.bellAudioEnabled = false
            config.bellAudioAdaptiveBuffering = false
            config.bellAudioNEONMixing = false
            config.bellAudioDrivenPacing = false
            config.bellAudioUnderrunProtection = false
            config.bellAudioDynamicRateCorrection = false
            config.bellAudioHQProcessing = false
          }
        } label: {
          HStack {
            Text(backend)
              .foregroundColor(.primary)
            Spacer()
            if config.audioBackend == backend {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Audio Backend")
  }
  
  private func getAvailableBackends() -> [String] {
    // iOS backends: CoreAudio (standard) and Bell (enhanced)
    // Note: Backend list comes from core via AudioCommon::GetSoundBackends()
    return ["CoreAudio", "Bell", "No Audio Output"]
  }
}

#if DEBUG
struct AudioBackendPickerView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AudioBackendPickerView()
    }
  }
}
#endif
