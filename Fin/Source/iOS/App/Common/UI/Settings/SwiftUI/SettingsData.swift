// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import SwiftUI

// MARK: - Settings Item

/// Represents a single setting item with metadata for search and display.
struct SettingsItem: Identifiable, Hashable {
  let id: String
  let title: String
  let description: String?
  let keywords: [String]
  let section: SettingsSection
  let type: SettingsItemType
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  static func == (lhs: SettingsItem, rhs: SettingsItem) -> Bool {
    lhs.id == rhs.id
  }
}

enum SettingsItemType {
  case toggle(keyPath: ReferenceWritableKeyPath<ConfigBridge, Bool>)
  case slider(keyPath: ReferenceWritableKeyPath<ConfigBridge, Float>, range: ClosedRange<Float>)
  case intSlider(keyPath: ReferenceWritableKeyPath<ConfigBridge, Int>, range: ClosedRange<Int>)
  case picker(destination: AnyView)
  case navigation(destination: AnyView)
  case action(() -> Void)
  case display(text: String)
}

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable, Identifiable {
  case cpu = "CPU"
  case video = "Video"
  case audio = "Audio"
  case config = "Config"
  case controllers = "Controllers"
  case extra = "Extra"
  case about = "About"
  
  var id: String { rawValue }
  
  var icon: String {
    switch self {
    case .cpu: return "bolt.fill"
    case .video: return "square.stack.3d.up.fill"
    case .audio: return "speaker.wave.3.fill"
    case .config: return "gearshape.fill"
    case .controllers: return "gamecontroller"
    case .extra: return "flask"
    case .about: return "info.circle"
    }
  }
}

@MainActor
final class SettingsData: ObservableObject {
  static let shared = SettingsData()
  
  @Published var searchText: String = ""
  @Published private(set) var allItems: [SettingsItem] = []
  
  private init() {
    buildAllItems()
  }
  
  var filteredItems: [SettingsItem] {
    guard !searchText.isEmpty else { return [] }
    let query = searchText.lowercased()
    return allItems.filter { item in
      item.title.lowercased().contains(query) ||
      item.description?.lowercased().contains(query) == true ||
      item.keywords.contains { $0.lowercased().contains(query) } ||
      item.section.rawValue.lowercased().contains(query)
    }
  }
  
  func items(for section: SettingsSection) -> [SettingsItem] {
    allItems.filter { $0.section == section }
  }
  
  private func buildAllItems() {
    allItems = []
    allItems.append(contentsOf: cpuItems)
    allItems.append(contentsOf: videoItems)
    allItems.append(contentsOf: audioItems)
    allItems.append(contentsOf: configItems)
    allItems.append(contentsOf: controllersItems)
    allItems.append(contentsOf: extraItems)
    allItems.append(contentsOf: aboutItems)
  }
  
  // MARK: - CPU Items
  
  private var cpuItems: [SettingsItem] {
    [
      SettingsItem(
        id: "emulation_speed",
        title: "Emulation Speed",
        description: "Limit or unlock the emulation speed",
        keywords: ["speed", "limit", "fps", "unlimited", "turbo", "fast", "slow", "100%"],
        section: .cpu,
        type: .navigation(destination: AnyView(EmulationSpeedPicker()))
      ),
      SettingsItem(
        id: "dual_core",
        title: "Dual Core",
        description: "Split CPU and GPU threads for better performance",
        keywords: ["cpu", "thread", "performance", "multicore", "parallel"],
        section: .cpu,
        type: .toggle(keyPath: \.dualCore)
      ),
      SettingsItem(
        id: "idle_skip",
        title: "Skip Idle on Sync",
        description: "Skip idle loops to reduce CPU load",
        keywords: ["idle", "skip", "sync", "cpu", "performance"],
        section: .cpu,
        type: .toggle(keyPath: \.idleSkip)
      ),
      SettingsItem(
        id: "interpreter_cache",
        title: "Code Cache Size",
        description: "CachedInterpreter code region size in MB",
        keywords: ["cache", "interpreter", "memory", "mb", "code"],
        section: .cpu,
        type: .navigation(destination: AnyView(InterpreterCachePicker()))
      ),
      SettingsItem(
        id: "fastmem",
        title: "Fastmem",
        description: "Fast memory access (may improve performance)",
        keywords: ["fastmem", "memory", "fast", "cpu"],
        section: .cpu,
        type: .toggle(keyPath: \.fastmem)
      ),
    ]
  }
  
  // MARK: - Video Items
  
  private var videoItems: [SettingsItem] {
    var items: [SettingsItem] = [
      SettingsItem(
        id: "internal_resolution",
        title: "Internal Resolution",
        description: "Render at higher resolutions for sharper graphics",
        keywords: ["resolution", "ir", "efb", "scale", "1x", "2x", "3x", "4x", "hd", "quality"],
        section: .video,
        type: .navigation(destination: AnyView(InternalResolutionPicker()))
      ),
      SettingsItem(
        id: "widescreen",
        title: "Widescreen Hack",
        description: "Force games to render in widescreen",
        keywords: ["widescreen", "16:9", "aspect", "ratio", "wide"],
        section: .video,
        type: .toggle(keyPath: \.widescreen)
      ),
      SettingsItem(
        id: "vsync",
        title: "V-Sync",
        description: "Synchronize with display refresh rate",
        keywords: ["vsync", "vertical", "sync", "tearing", "refresh"],
        section: .video,
        type: .toggle(keyPath: \.vsync)
      ),
      SettingsItem(
        id: "graphics_mods",
        title: "Graphics Mods",
        description: "Enable graphics modification packs",
        keywords: ["mods", "texture", "graphics", "packs"],
        section: .video,
        type: .toggle(keyPath: \.graphicsMods)
      ),
      SettingsItem(
        id: "show_fps",
        title: "Show FPS",
        description: "Display frames per second on screen",
        keywords: ["fps", "framerate", "display", "counter"],
        section: .video,
        type: .toggle(keyPath: \.showFPS)
      ),
      SettingsItem(
        id: "show_speed",
        title: "Show Speed",
        description: "Display emulation speed percentage",
        keywords: ["speed", "percentage", "display"],
        section: .video,
        type: .toggle(keyPath: \.showSpeed)
      ),
      SettingsItem(
        id: "backend_multithreading",
        title: "Backend Multithreading",
        description: "Enable multithreaded graphics backend",
        keywords: ["multithreading", "thread", "backend", "vulkan"],
        section: .video,
        type: .toggle(keyPath: \.backendMultithreading)
      ),
      SettingsItem(
        id: "load_custom_textures",
        title: "Custom Textures",
        description: "Load custom texture packs",
        keywords: ["textures", "custom", "hd", "packs"],
        section: .video,
        type: .toggle(keyPath: \.loadCustomTextures)
      ),
    ]
    
    // MetalFX items (iOS 16+)
    if #available(iOS 16.0, *) {
      items.append(contentsOf: [
        SettingsItem(
          id: "metalfx_upscaling",
          title: "MetalFX Upscaling",
          description: "Use Metal FX spatial upscaling for better performance",
          keywords: ["metalfx", "metal", "upscaling", "upscale", "fsr", "performance"],
          section: .video,
          type: .toggle(keyPath: \.metalFXUpscaling)
        ),
        SettingsItem(
          id: "metalfx_resolution",
          title: "MetalFX Output Resolution",
          description: "Target resolution for MetalFX upscaling",
          keywords: ["metalfx", "resolution", "output", "target"],
          section: .video,
          type: .navigation(destination: AnyView(MetalFXResolutionPicker()))
        ),
      ])
    }
    
    return items
  }
  
  // MARK: - Audio Items
  
  private var audioItems: [SettingsItem] {
    [
      SettingsItem(
        id: "audio_volume",
        title: "Audio Volume",
        description: "Master audio volume",
        keywords: ["audio", "volume", "sound", "loud", "quiet"],
        section: .audio,
        type: .intSlider(keyPath: \.audioVolume, range: 0...100)
      ),
      SettingsItem(
        id: "audio_stretch",
        title: "Audio Stretching",
        description: "Stretch audio to match emulation speed",
        keywords: ["audio", "stretch", "sync", "timing"],
        section: .audio,
        type: .toggle(keyPath: \.audioStretch)
      ),
      SettingsItem(
        id: "osd_messages",
        title: "OSD Messages",
        description: "Show on-screen messages during gameplay",
        keywords: ["osd", "messages", "display", "notifications"],
        section: .audio,
        type: .toggle(keyPath: \.osdMessages)
      ),
    ]
  }
  
  // MARK: - Config Items
  
  private var configItems: [SettingsItem] {
    [
      SettingsItem(
        id: "game_covers",
        title: "Show Game Covers",
        description: "Display game cover art in the library",
        keywords: ["covers", "art", "library", "images"],
        section: .config,
        type: .toggle(keyPath: \.useGameCovers)
      ),
      SettingsItem(
        id: "confirm_stop",
        title: "Confirm on Stop",
        description: "Ask for confirmation when stopping emulation",
        keywords: ["confirm", "stop", "exit", "quit"],
        section: .config,
        type: .toggle(keyPath: \.confirmOnStop)
      ),
      SettingsItem(
        id: "wii_progressive",
        title: "Wii Progressive Scan",
        description: "Enable progressive scan mode for Wii",
        keywords: ["wii", "progressive", "scan", "480p"],
        section: .config,
        type: .toggle(keyPath: \.wiiProgressiveScan)
      ),
      SettingsItem(
        id: "region_mismatch",
        title: "Allow Region Mismatch",
        description: "Allow games from different regions",
        keywords: ["region", "mismatch", "ntsc", "pal", "japan"],
        section: .config,
        type: .toggle(keyPath: \.mismatchedRegionSettings)
      ),
      SettingsItem(
        id: "auto_disc_change",
        title: "Auto Disc Change",
        description: "Automatically swap discs for multi-disc games",
        keywords: ["disc", "change", "swap", "multi"],
        section: .config,
        type: .toggle(keyPath: \.autoDiscChange)
      ),
    ]
  }
  
  // MARK: - Controllers Items
  
  private var controllersItems: [SettingsItem] {
    [
      SettingsItem(
        id: "touchscreen_opacity",
        title: "Touchscreen Opacity",
        description: "Adjust the visibility of touch controls",
        keywords: ["touch", "opacity", "transparent", "controls", "visibility"],
        section: .controllers,
        type: .slider(keyPath: \.touchPadOpacity, range: 0...1)
      ),
      SettingsItem(
        id: "touchscreen_ir_mode",
        title: "Wii IR Mode",
        description: "How the touchscreen controls Wii pointer",
        keywords: ["wii", "ir", "pointer", "touch", "mode"],
        section: .controllers,
        type: .navigation(destination: AnyView(TouchIRModePicker()))
      ),
      SettingsItem(
        id: "controller_port_1",
        title: "Port 1",
        description: "Configure controller for port 1",
        keywords: ["port", "controller", "gamecube", "gc", "1"],
        section: .controllers,
        type: .navigation(destination: AnyView(ControllerPortView(port: 0)))
      ),
      SettingsItem(
        id: "controller_port_2",
        title: "Port 2",
        description: "Configure controller for port 2",
        keywords: ["port", "controller", "gamecube", "gc", "2"],
        section: .controllers,
        type: .navigation(destination: AnyView(ControllerPortView(port: 1)))
      ),
      SettingsItem(
        id: "controller_port_3",
        title: "Port 3",
        description: "Configure controller for port 3",
        keywords: ["port", "controller", "gamecube", "gc", "3"],
        section: .controllers,
        type: .navigation(destination: AnyView(ControllerPortView(port: 2)))
      ),
      SettingsItem(
        id: "controller_port_4",
        title: "Port 4",
        description: "Configure controller for port 4",
        keywords: ["port", "controller", "gamecube", "gc", "4"],
        section: .controllers,
        type: .navigation(destination: AnyView(ControllerPortView(port: 3)))
      ),
    ]
  }
  
  // MARK: - Extra Items
  
  private var extraItems: [SettingsItem] {
    [
      SettingsItem(
        id: "panic_handlers",
        title: "Panic Handlers",
        description: "Show alerts on emulation errors",
        keywords: ["panic", "handler", "error", "alert", "debug"],
        section: .extra,
        type: .toggle(keyPath: \.panicHandlers)
      ),
    ]
  }
  
  // MARK: - About Items
  
  private var aboutItems: [SettingsItem] {
    [
      SettingsItem(
        id: "about_version",
        title: "Version",
        description: nil,
        keywords: ["version", "build", "number"],
        section: .about,
        type: .display(text: VersionManager.shared().appVersion.userFacing)
      ),
      SettingsItem(
        id: "about_core",
        title: "Dolphin Core",
        description: nil,
        keywords: ["core", "dolphin", "emulator", "version"],
        section: .about,
        type: .display(text: VersionManager.shared().coreVersion)
      ),
      SettingsItem(
        id: "about_update",
        title: "Check for Updates",
        description: "See if a newer version is available",
        keywords: ["update", "new", "version", "check"],
        section: .about,
        type: .navigation(destination: AnyView(UpdateCheckView()))
      ),
    ]
  }
}

struct EmulationSpeedPicker: View {
  var body: some View {
    Text("Emulation Speed Picker")
  }
}

struct InterpreterCachePicker: View {
  var body: some View {
    Text("Interpreter Cache Picker")
  }
}

struct InternalResolutionPicker: View {
  var body: some View {
    Text("Internal Resolution Picker")
  }
}

struct MetalFXResolutionPicker: View {
  var body: some View {
    Text("MetalFX Resolution Picker")
  }
}

struct TouchIRModePicker: View {
  var body: some View {
    Text("Touch IR Mode Picker")
  }
}

struct ControllerPortView: View {
  let port: Int
  var body: some View {
    MappingRootView(mappingType: .pad, port: port)
  }
}

struct UpdateCheckView: View {
  var body: some View {
    Text("Update Check")
  }
}
