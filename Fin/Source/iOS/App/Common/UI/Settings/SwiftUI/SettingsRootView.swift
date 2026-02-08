// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

private struct SettingsGridItem: Identifiable {
  let id: String
  let title: String
  let icon: String
  let destination: AnyView?
}

struct ControllerMappingRequest: Identifiable {
  let mappingType: MappingType
  let port: Int
  let forceTouchscreen: Bool
  var id: String { "\(mappingType == .pad ? "gc" : "wii")-\(port)-\(forceTouchscreen ? "touch" : "normal")" }
}

struct SettingsRootView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedItem: SettingsGridItem?
  @State private var activePreset: String?
  @State private var mappingRequest: ControllerMappingRequest?

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]

  private var items: [SettingsGridItem] {
    [
      SettingsGridItem(id: "cpu", title: "CPU", icon: "bolt.fill",
                       destination: AnyView(CPUSettingsView())),
      SettingsGridItem(id: "video", title: "Video", icon: "square.stack.3d.up.fill",
                       destination: AnyView(VideoSettingsView())),
      SettingsGridItem(id: "audio", title: "Audio", icon: "speaker.wave.3.fill",
                       destination: AnyView(AudioSettingsView())),
      SettingsGridItem(id: "config", title: "Config", icon: "gearshape.fill",
                       destination: AnyView(CoreSettingsView())),
      SettingsGridItem(id: "controllers", title: "Controllers", icon: "gamecontroller.fill",
                       destination: nil),
      SettingsGridItem(id: "extra", title: "Extra", icon: "flask.fill",
                       destination: AnyView(ExperimentalSettingsView())),
      SettingsGridItem(id: "about", title: "About", icon: "info.circle",
                       destination: AnyView(AboutView())),
      SettingsGridItem(id: "fast", title: "Fast", icon: "hare.fill",
                       destination: AnyView(presetDetailView(preset: "fast"))),
      SettingsGridItem(id: "fastest", title: "Fastest", icon: "flame.fill",
                       destination: AnyView(presetDetailView(preset: "fastest"))),
    ]
  }

  @Environment(\.verticalSizeClass) private var verticalSizeClass

  var body: some View {
    ZStack {
      Group {
        if verticalSizeClass == .compact {
          landscapeBody
        } else {
          portraitBody
        }
      }
      .background { AppBackground() }
      .onAppear {
        ConfigBridge.shared.reload()
      }
      .sheet(item: $mappingRequest, onDismiss: {
        NotificationCenter.default.post(name: .init("ControllersRefreshDevices"), object: nil)
      }) { req in
        if req.forceTouchscreen {
          TouchMappingRootView(mappingType: req.mappingType, port: req.port)
        } else {
          MappingRootView(mappingType: req.mappingType, port: req.port)
        }
      }

      // Portrait popup overlay
      if verticalSizeClass != .compact, let item = selectedItem {
        GeometryReader { geo in
          ZStack {
            Color.black.opacity(0.5)
              .ignoresSafeArea()
              .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { selectedItem = nil } }

            VStack(spacing: 0) {
              Text(item.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.15 : 0.6))

              Divider()

              NavigationView {
                Group {
                  if item.id == "controllers" {
                    ControllersPopupView(mappingRequest: $mappingRequest)
                  } else {
                    item.destination
                  }
                }
                .navigationBarHidden(true)
              }
              .navigationViewStyle(.stack)
            }
            .frame(
              maxWidth: min(geo.size.width - 48, 380),
              maxHeight: geo.size.height * 0.65
            )
            .background(colorScheme == .dark ? Color.black.opacity(0.96) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)

            Text("Tap anywhere to close")
              .font(.system(size: 11))
              .foregroundColor(.secondary)
              .offset(y: geo.size.height * 0.325 + 20)
          }
        }
        .transition(.opacity)
      }
    }
  }

  // MARK: - Portrait layout (full width, popup overlay)

  private var portraitBody: some View {
    VStack(spacing: 0) {
      Text("Settings")
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
        .padding(.bottom, 12)

      ScrollView {
        settingsGridContent
      }
    }
  }

  // MARK: - Landscape layout (split: settings left, detail right)

  private var landscapeBody: some View {
    HStack(spacing: 0) {
      // Left: settings grid
      VStack(spacing: 0) {
        Text("Settings")
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.primary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 8)
          .padding(.bottom, 8)

        ScrollView {
          settingsGridContent
        }
      }
      .frame(maxWidth: 280)

      Divider()

      // Right: selected setting detail
      if let item = selectedItem {
        VStack(spacing: 0) {
          HStack {
            Text(item.title)
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.primary)
            Spacer()
            Button {
              withAnimation(.easeOut(duration: 0.2)) { selectedItem = nil }
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.15 : 0.6))

          Divider()

          NavigationView {
            Group {
              if item.id == "controllers" {
                ControllersPopupView(mappingRequest: $mappingRequest)
              } else {
                item.destination
              }
            }
            .navigationBarHidden(true)
          }
          .navigationViewStyle(.stack)
        }
      } else {
        VStack {
          Spacer()
          Image(systemName: "gearshape")
            .font(.system(size: 48))
            .foregroundColor(.secondary.opacity(0.4))
          Text("Select a setting")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.top, 8)
          Spacer()
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  // MARK: - Shared grid content

  private var settingsGridContent: some View {
    LazyVGrid(columns: columns, spacing: 12) {
      ForEach(items) { item in
        Button {
          if item.id == "fast" || item.id == "fastest" {
            applyPreset(item.id)
            withAnimation(.easeInOut(duration: 0.25)) { activePreset = item.id }
          }
          withAnimation(.easeOut(duration: 0.2)) { selectedItem = item }
        } label: {
          settingsCell(item)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 16)
  }

  private func settingsCell(_ item: SettingsGridItem) -> some View {
    let isPreset = item.id == "fast" || item.id == "fastest"
    let isActive = isPreset && activePreset == item.id
    let presetColor: Color = item.id == "fast" ? .orange : item.id == "fastest" ? .red : .clear
    return VStack(spacing: 6) {
      Image(systemName: item.icon)
        .font(.system(size: 36))
        .foregroundColor(isActive ? .white : (isPreset ? presetColor : .accentColor))
        .frame(height: 44)
      Text(item.title)
        .font(.caption2)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .foregroundColor(isActive ? .white : .primary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isActive ? presetColor : Color(uiColor: .secondarySystemGroupedBackground))
    )
  }

  private func presetDetailView(preset: String) -> some View {
    let items: [(String, String)] = preset == "fast" ? [
      ("Cached Interpreter", "Good speed with decent compatibility"),
      ("Dual Core", "CPU and GPU on separate threads"),
      ("DSP HLE", "Faster audio processing"),
      ("Fast Disc Speed", "Shorter load times"),
      ("Skip EFB Access", "Skips slow framebuffer reads"),
      ("GPU Texture Decoding", "Offloads texture work to GPU"),
      ("Async + Uber Shaders", "Smooth shader compilation"),
    ] : [
      ("Inline Cached Interpreter", "Aggressive optimizations for max speed"),
      ("Dual Core", "CPU and GPU on separate threads"),
      ("DSP HLE", "Faster audio processing"),
      ("Fast Disc Speed", "Shorter load times"),
      ("Skip EFB + VI Skip", "Skips framebuffer reads and extra frames"),
      ("No Mipmapping", "Saves GPU work, may look rougher"),
      ("Async + Skip Shaders", "Fastest compilation, may flash"),
    ]
    return List {
      Section {
        ForEach(items, id: \.0) { item in
          VStack(alignment: .leading, spacing: 2) {
            Text(item.0)
              .font(.system(size: 14, weight: .medium))
            Text(item.1)
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 2)
        }
      } header: {
        Text("This preset enables")
      } footer: {
        Text(preset == "fast" ? "Good balance of speed and compatibility." : "Maximum speed — may cause visual glitches in some games.")
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(preset == "fast" ? "Fast Preset" : "Fastest Preset")
  }

  private func applyPreset(_ preset: String) {
    let config = ConfigBridge.shared
    switch preset {
    case "safe":
      config.cpuCore = 0            // Interpreter
      config.dualCore = false
      config.idleSkip = false
      config.fastDiscSpeed = false
      config.dspHLE = false
      config.syncGPU = true
      config.skipEFBAccess = false
      config.deferEFBInvalidation = false
      config.deferEFBCopies = false
      config.efbEmulateFormatChanges = true
      config.skipEFBCopyToRAM = false
      config.skipXFBCopyToRAM = false
      config.fastDepthCalc = false
      config.viSkip = false
      config.backendMultithreading = true
      config.shaderCompilationMode = 0
      config.fastTextureSampling = false
      config.noMipmapping = false
      config.gpuTextureDecoding = false
    case "fast":
      config.cpuCore = 1            // Cached Interpreter
      config.dualCore = true
      config.idleSkip = true
      config.fastDiscSpeed = true
      config.dspHLE = true
      config.syncGPU = false
      config.skipEFBAccess = true
      config.deferEFBInvalidation = true
      config.deferEFBCopies = true
      config.efbEmulateFormatChanges = false
      config.skipEFBCopyToRAM = true
      config.skipXFBCopyToRAM = true
      config.fastDepthCalc = true
      config.viSkip = false
      config.backendMultithreading = true
      config.shaderCompilationMode = 2
      config.fastTextureSampling = true
      config.noMipmapping = false
      config.gpuTextureDecoding = true
    case "fastest":
      config.cpuCore = 2            // Inline Cached Interpreter
      config.dualCore = true
      config.idleSkip = true
      config.fastDiscSpeed = true
      config.dspHLE = true
      config.syncGPU = false
      config.skipEFBAccess = true
      config.deferEFBInvalidation = true
      config.deferEFBCopies = true
      config.efbEmulateFormatChanges = false
      config.skipEFBCopyToRAM = true
      config.skipXFBCopyToRAM = true
      config.fastDepthCalc = true
      config.viSkip = true
      config.backendMultithreading = true
      config.shaderCompilationMode = 3
      config.fastTextureSampling = true
      config.noMipmapping = true
      config.gpuTextureDecoding = true
    default:
      break
    }
    config.reload()
  }
}

#if DEBUG
struct SettingsRootView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsRootView()
  }
}
#endif
