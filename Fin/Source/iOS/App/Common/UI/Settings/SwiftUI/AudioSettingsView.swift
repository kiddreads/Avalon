// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Audio – volume, DSP, backend, Bell audio, spatial audio.
struct AudioSettingsView: View {
  @StateObject private var config = ConfigBridge.shared
  
  var body: some View {
    List {
      // Volume & Core
      Section {
        VStack(alignment: .leading) {
          HStack {
            Text("Volume")
            Spacer()
            Text("\(config.audioVolume)%")
              .foregroundColor(.secondary)
          }
          Slider(value: Binding(
            get: { Double(config.audioVolume) },
            set: { config.audioVolume = Int($0) }
          ), in: 0...100, step: 1)
        }
        
        SettingRow("DSP HLE", isOn: $config.dspHLE, info: "Faster audio processing. Turn it off if a game's sound is broken.")
        Toggle("Audio Stretching", isOn: $config.audioStretch)
        Toggle("Mute Audio", isOn: $config.audioMuted)
      } header: {
        Text("General")
      }
      
      // Latency & Buffer
      Section {
        NavigationLink {
          AudioLatencyPickerView()
        } label: {
          HStack {
            Text("Latency")
            Spacer()
            Text("\(config.audioLatency) ms")
              .foregroundColor(.secondary)
          }
        }
        
        NavigationLink {
          AudioBackendPickerView()
        } label: {
          HStack {
            Text("Backend")
            Spacer()
            Text(config.audioBackend)
              .foregroundColor(.secondary)
          }
        }
        
        NavigationLink {
          AudioBufferSizePickerView()
        } label: {
          HStack {
            Text("Buffer Size")
            Spacer()
            Text("\(config.audioBufferSize) ms")
              .foregroundColor(.secondary)
          }
        }
      } header: {
        Text("Latency & Backend")
      }
      
      // Output
      Section {
        Picker("Output", selection: $config.audioOutputMode) {
          Text("Mono").tag(0)
          Text("Stereo").tag(1)
          Text("Surround").tag(2)
        }
        
        SettingRow("Audio Upsampling", isOn: $config.audioUpsampling, info: "Bumps the sample rate to 96 kHz for cleaner audio.")
        Toggle("DPL2 Surround Decoder", isOn: $config.dpl2Decoder)
        SettingRow("Prefer Spatial Audio", isOn: $config.preferSpatialAudio, info: "Works with AirPods Pro and other spatial audio headphones.")
      } header: {
        Text("Output")
      }
      
      // Bell Audio (shown when Bell backend is selected)
      if config.audioBackend == "Bell" {
        Section {
          Toggle("Bell Audio Enabled", isOn: $config.bellAudioEnabled)
          Toggle("Adaptive Buffering", isOn: $config.bellAudioAdaptiveBuffering)
          Toggle("NEON Mixing", isOn: $config.bellAudioNEONMixing)
          Toggle("Audio-Driven Frame Pacing", isOn: $config.bellAudioDrivenPacing)
          Toggle("Underrun Protection", isOn: $config.bellAudioUnderrunProtection)
          Toggle("Dynamic Rate Correction", isOn: $config.bellAudioDynamicRateCorrection)
          Toggle("HQ Processing", isOn: $config.bellAudioHQProcessing)
        } header: {
          Text("Bell Audio")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Audio")
  }
}

#if DEBUG
struct AudioSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AudioSettingsView()
    }
  }
}
#endif
