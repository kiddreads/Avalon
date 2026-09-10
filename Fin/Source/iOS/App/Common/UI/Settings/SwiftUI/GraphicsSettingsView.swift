// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Video – resolution, display, filtering, enhancements, EFB/XFB, hacks, textures, Metal, MetalFX, post-processing.
struct VideoSettingsView: View {
  @StateObject private var config = ConfigBridge.shared
  
  private var internalResolutionDisplay: String {
    let scale = config.internalResolution
    return scale <= 0 ? "1x" : "\(scale)x"
  }
  
  var body: some View {
    List {
      Section {
        Toggle("V-Sync", isOn: $config.vsync)
        Toggle("Backend Multithreading", isOn: $config.backendMultithreading)
      } header: {
        Text("Basic")
      }
      
      Section {
        Toggle("Show FPS", isOn: $config.showFPS)
        Toggle("Show Speed", isOn: $config.showSpeed)
        Toggle("OSD Messages", isOn: $config.osdMessages)
      } header: {
        Text("Display")
      }
      
      Section("Aspect Ratio") {
        Picker("Aspect Ratio", selection: $config.aspectRatio) {
          Text("Auto").tag(0)
          Text("Force 16:9").tag(1)
          Text("Force 4:3").tag(2)
          Text("Stretch").tag(3)
          Text("Custom").tag(4)
          Text("Custom Stretch").tag(5)
          Text("Raw").tag(6)
        }
      }
      
      Section {
        NavigationLink {
          InternalResolutionPickerView()
        } label: {
          HStack {
            Text("Internal Resolution")
            Spacer()
            Text(internalResolutionDisplay)
              .foregroundColor(.secondary)
          }
        }
      } header: {
        Text("Resolution")
      }
      
      Section {
        Picker("Texture Filtering", selection: $config.textureFiltering) {
          Text("Default").tag(0)
          Text("Force Nearest").tag(1)
          Text("Force Linear").tag(2)
        }
        Picker("Anisotropic Filtering", selection: $config.anisotropicFiltering) {
          Text("Default").tag(0)
          Text("2x").tag(2)
          Text("4x").tag(3)
          Text("8x").tag(4)
          Text("16x").tag(5)
        }
        HStack {
          Picker("Output Resampling", selection: $config.outputResampling) {
            Text("Default").tag(0)
            Text("Bilinear").tag(1)
            Text("BSpline").tag(2)
            Text("Mitchell-Netravali").tag(3)
            Text("Catmull-Rom").tag(4)
            Text("Sharp Bilinear").tag(5)
            Text("Area").tag(6)
          }
          SettingInfoButton(info: "Changes how the final image gets scaled to your screen. Higher quality options look sharper but cost a bit of performance.")
        }
      } header: {
        Text("Filtering")
      }
      
      Section {
        Toggle("Widescreen Hack", isOn: $config.widescreen)
        SettingRow("Per-Pixel Lighting", isOn: $config.pixelLighting, info: "Better lighting, but heavier on the GPU.")
        SettingRow("SSAA", isOn: $config.ssaa, info: "Renders at a higher resolution then scales down. Looks great, but very demanding.")
        Toggle("Force True Color", isOn: $config.forceTrueColor)
        Toggle("Disable Copy Filter", isOn: $config.disableCopyFilter)
        Toggle("Arbitrary Mipmap Detection", isOn: $config.arbitraryMipmapDetection)
        if config.arbitraryMipmapDetection {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text("Mipmap Detection Threshold")
              Spacer()
              Text(String(format: "%.0f", config.arbitraryMipmapDetectionThreshold))
                .foregroundColor(.secondary)
            }
            Slider(value: $config.arbitraryMipmapDetectionThreshold, in: 1...30, step: 1)
          }
        }
        Toggle("Disable Fog", isOn: $config.disableFog)
        SettingRow("HDR Output", isOn: $config.hdrOutput, info: "Needs a display that supports HDR. Makes colors pop on compatible screens.")
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Exposure")
            SettingInfoButton(info: "Controls brightness for HDR. 1.0 is default — go higher to brighten, lower to dim.")
            Spacer()
            Text(String(format: "%.2f", config.exposure))
              .foregroundColor(.secondary)
          }
          Slider(value: $config.exposure, in: 0.25...2.5, step: 0.05)
        }
      } header: {
        Text("Enhancements")
      }
      
      Section {
        Toggle("Skip EFB Access from CPU", isOn: $config.skipEFBAccess)
        Toggle("Store EFB Copies to Texture Only", isOn: $config.skipEFBCopyToRAM)
        Toggle("Defer EFB Copies", isOn: $config.deferEFBCopies)
        Toggle("Ignore Format Changes", isOn: Binding(
          get: { !config.efbEmulateFormatChanges },
          set: { config.efbEmulateFormatChanges = !$0 }
        ))
        Toggle("Defer EFB Copies to RAM", isOn: $config.deferEFBInvalidation)
      } header: {
        Text("Embedded Frame Buffer (EFB)")
      }
      
      Section {
        HStack {
          Picker("Accuracy", selection: $config.textureCacheAccuracy) {
            Text("Safe").tag(0)
            Text("Medium").tag(512)
            Text("Fast").tag(128)
          }
          SettingInfoButton(info: "Safe catches more texture issues but is slower. Fast is quicker but some games may glitch.")
        }
        Toggle("GPU Texture Decoding", isOn: $config.gpuTextureDecoding)
      } header: {
        Text("Texture Cache")
      }
      
      Section {
        Toggle("Store XFB Copies to Texture Only", isOn: $config.skipXFBCopyToRAM)
        Toggle("Immediately Present XFB", isOn: $config.immediateXFB)
        SettingRow("Early XFB Output", isOn: $config.earlyXFBOutput, info: "Can cut down on input lag.")
        Toggle("Skip Presenting Duplicate Frames", isOn: $config.skipDuplicateXFBs)
      } header: {
        Text("External Frame Buffer (XFB)")
      }
      
      Section {
        Toggle("Fast Depth Calculation", isOn: $config.fastDepthCalc)
        Toggle("Vertex Rounding", isOn: $config.vertexRounding)
        Toggle("Disable Bounding Box", isOn: Binding(
          get: { !config.boundingBoxEnable },
          set: { config.boundingBoxEnable = !$0 }
        ))
        Toggle("Save Texture Cache to State", isOn: $config.saveTextureCacheToState)
        Toggle("VI Skip", isOn: $config.viSkip)
        Toggle("Fast Texture Sampling", isOn: $config.fastTextureSampling)
        Toggle("Force Progressive Scan", isOn: $config.forceProgressiveScan)
        Toggle("Copy EFB Scaled", isOn: $config.copyEFBScaled)
        Toggle("Disable Copy to VRAM", isOn: $config.disableCopyToVRAM)
        Toggle("No Mipmapping", isOn: $config.noMipmapping)
      } header: {
        Text("Other Hacks")
      }
      
      Section {
        Toggle("Load Custom Textures", isOn: $config.loadCustomTextures)
        SettingRow("Cache Hi-Res Textures", isOn: $config.cacheHiresTextures, info: "Keeps custom textures in memory so they load faster. Uses more RAM.")
        Toggle("Graphics Mods", isOn: $config.graphicsMods)
      } header: {
        Text("Textures")
      }
      
      Section {
        SettingRow("GPU Vertex Decoding", isOn: $config.useGPUVertexDecode, info: "Lets the GPU handle vertex conversion. Turn it off if you see weird visuals.")
        SettingRow("Native Video Decode", isOn: $config.useNativeVideoDecode, info: "Uses hardware decoding for cutscenes. Smoother playback with less CPU work.")
      } header: {
        Text("Metal")
      }
      
      if #available(iOS 16.0, *) {
        Section {
          Toggle("Enable", isOn: $config.metalFXUpscaling)
          if config.metalFXUpscaling {
            Text("Output: 1.25× Internal Resolution")
              .foregroundColor(.secondary)
              .font(.footnote)
          }
        } header: {
          Text("MetalFX Upscaling")
        }
      }
      
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Video")
  }
}

// MARK: - Internal Resolution Picker

struct InternalResolutionPickerView: View {
  @StateObject private var config = ConfigBridge.shared
  
  private let resolutions: [(String, Int)] = [
    ("1x Native (640x528)", 1),
    ("2x Native (1280x1056)", 2),
    ("3x Native (1920x1584)", 3),
    ("4x Native (2560x2112)", 4),
    ("5x Native (3200x2640)", 5),
    ("6x Native (3840x3168)", 6),
  ]
  
  var body: some View {
    List {
      ForEach(resolutions, id: \.1) { option in
        Button {
          config.internalResolution = option.1
        } label: {
          HStack {
            Text(option.0)
              .foregroundColor(.primary)
            Spacer()
            if config.internalResolution == option.1 {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Internal Resolution")
  }
}

// MARK: - Post-Processing Shader Picker

struct PostProcessingSettingsView: View {
  @StateObject private var config = ConfigBridge.shared
  @State private var shaderNames: [String] = ["None"]
  @State private var selectedShaders: Set<String> = []
  @State private var showDownloadSheet = false
  @State private var lastDownloadMessage: String?
  @Environment(\.openURL) private var openURL
  
  var body: some View {
    List {
      Section {
        ForEach(shaderNames, id: \.self) { name in
          let isNone = name == "None"
          let selected = isNone
            ? selectedShaders.isEmpty
            : selectedShaders.contains(name)
          Button {
            if isNone {
              selectedShaders.removeAll()
              saveSelectedShaders()
              config.postProcessingShader = ""
            } else {
              if selectedShaders.contains(name) {
                selectedShaders.remove(name)
              } else {
                selectedShaders.insert(name)
              }
              saveSelectedShaders()
              applyFirstSelectedShader()
            }
          } label: {
            HStack {
              Text(name)
                .foregroundColor(.primary)
              Spacer()
              if selected {
                Image(systemName: "checkmark")
                  .foregroundColor(.accentColor)
              }
            }
          }
        }
      } header: {
        Text("Shaders (first enabled is active)")
      }
      
      Section("Get more shaders") {
        Button {
          showDownloadSheet = true
        } label: {
          Label("Download shader from URL…", systemImage: "square.and.arrow.down")
        }
        
        Button {
          if let url = URL(string: "https://github.com/libretro/slang-shaders") {
            openURL(url)
          }
        } label: {
          Label("Open libretro slang-shaders", systemImage: "link")
        }
        
        Button {
          if let url = URL(string: "https://github.com/bloc97/Anime4K") {
            openURL(url)
          }
        } label: {
          Label("Open Anime4K repo", systemImage: "link")
        }
        
        if let message = lastDownloadMessage, !message.isEmpty {
          Text(message)
            .font(.footnote)
            .foregroundColor(.secondary)
        }

          NavigationLink {
            RemoteLibretroShaderBrowserView()
          } label: {
            Label("Browse libretro slang-shaders…", systemImage: "folder")
          }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Post-Processing")
    .onAppear {
      refreshShaderList()
      let saved = UserDefaults.standard.stringArray(forKey: "DOLSelectedPostProcessingShaders") ?? []
      selectedShaders = Set(saved)
      // If there's an active shader not in the saved set, add it
      let current = config.postProcessingShader
      if !current.isEmpty && !selectedShaders.contains(current) {
        selectedShaders.insert(current)
      }
    }
    .sheet(isPresented: $showDownloadSheet) {
      ShaderDownloadView { status in
        lastDownloadMessage = status
        refreshShaderList()
      }
    }
  }
  
  private func saveSelectedShaders() {
    UserDefaults.standard.set(Array(selectedShaders), forKey: "DOLSelectedPostProcessingShaders")
  }
  
  private func applyFirstSelectedShader() {
    let active = shaderNames
      .filter { $0 != "None" }
      .first { selectedShaders.contains($0) } ?? ""
    config.postProcessingShader = active
  }
  
  private func refreshShaderList() {
    var dirPath = DOLConfigBridge.shadersDirectoryPath() ?? ""
    if dirPath.isEmpty, let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      dirPath = docs.appendingPathComponent("Shaders", isDirectory: true).path
    }
    guard !dirPath.isEmpty else {
      shaderNames = ["None"]
      return
    }
    let path = dirPath
    DispatchQueue.global(qos: .userInitiated).async {
      _ = try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
      var nameSet: Set<String> = []
      let allowedSuffixes = [".glsl", ".glslp", ".slang", ".slangp"]
      if let enumerator = FileManager.default.enumerator(atPath: path) {
        while let file = enumerator.nextObject() as? String {
          guard !file.hasPrefix(".") else { continue }
          guard allowedSuffixes.contains(where: { file.hasSuffix($0) }) else { continue }
          let name = (file as NSString).lastPathComponent
          let baseName = (name as NSString).deletingPathExtension
          if !baseName.isEmpty && baseName != "default_pre_post_process" { nameSet.insert(baseName) }
        }
      }
      var names = Array(nameSet)
      names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
      let result = ["None"] + names
      DispatchQueue.main.async {
        shaderNames = result
      }
    }
  }
}

// MARK: - Remote libretro browser

private struct RemoteLibretroEntry: Identifiable {
  let id: String
  let name: String
  let path: String
  let isDirectory: Bool
}

struct RemoteLibretroShaderBrowserView: View {
  // Root is empty string, e.g. "crt", "hdr/..." for subfolders
  let path: String
  
  @State private var entries: [RemoteLibretroEntry] = []
  @State private var isLoading = false
  @State private var errorMessage: String = ""
  @State private var downloadStatus: String = ""
  
  init(path: String = "") {
    self.path = path
  }
  
  var body: some View {
    List {
      if isLoading {
        Section {
          ProgressView("Loading…")
        }
      }
      
      if !errorMessage.isEmpty {
        Section {
          Text(errorMessage)
            .foregroundColor(.red)
        }
      }

      let shaderFiles = entries.filter {
        !$0.isDirectory &&
          ($0.name.lowercased().hasSuffix(".slang") ||
           $0.name.lowercased().hasSuffix(".slangp") ||
           $0.name.lowercased().hasSuffix(".glsl") ||
           $0.name.lowercased().hasSuffix(".glslp"))
      }
      let allFiles = entries.filter { !$0.isDirectory }
      if !allFiles.isEmpty {
        Section {
          Button {
            downloadAllShaders(in: allFiles)
          } label: {
            Label("Download all files in this folder", systemImage: "tray.and.arrow.down")
          }
        }
      }
      
      Section {
        ForEach(entries.filter { $0.isDirectory }) { entry in
          NavigationLink {
            RemoteLibretroShaderBrowserView(path: entry.path)
          } label: {
            Label(entry.name, systemImage: "folder")
          }
        }
      }
      
      Section {
        ForEach(shaderFiles) { entry in
          HStack {
            Text(entry.name)
            Spacer()
            Button {
              downloadRemoteFile(entry: entry)
            } label: {
              Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
          }
        }
      }
      
      if !downloadStatus.isEmpty {
        Section {
          Text(downloadStatus)
            .font(.footnote)
            .foregroundColor(.secondary)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(path.isEmpty ? "libretro shaders" : path)
    .onAppear {
      if entries.isEmpty && !isLoading {
        loadDirectory()
      }
    }
  }
  
  private func loadDirectory() {
    isLoading = true
    errorMessage = ""
    
    let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
    let base = "https://api.github.com/repos/libretro/slang-shaders/contents"
    let urlString = encodedPath.isEmpty ? base : "\(base)/\(encodedPath)"
    guard let url = URL(string: urlString) else {
      isLoading = false
      errorMessage = "Invalid GitHub URL."
      return
    }
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
      DispatchQueue.main.async {
        isLoading = false
        if let error = error {
          errorMessage = "Failed to load: \(error.localizedDescription)"
          return
        }
        guard
          let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode),
          let data = data
        else {
          errorMessage = "Failed to load directory."
          return
        }
        
        struct GitHubContent: Decodable {
          let name: String
          let path: String
          let type: String
        }
        
        do {
          let decoded = try JSONDecoder().decode([GitHubContent].self, from: data)
          let mapped = decoded.map { item -> RemoteLibretroEntry in
            RemoteLibretroEntry(
              id: item.path,
              name: item.name,
              path: item.path,
              isDirectory: item.type == "dir"
            )
          }
          let dirs = mapped
            .filter { $0.isDirectory }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
          let files = mapped
            .filter { !$0.isDirectory }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
          entries = dirs + files
        } catch {
          errorMessage = "Failed to parse GitHub response."
        }
      }
    }
    task.resume()
  }
  
  private func shadersDirectory() -> String? {
    var dirPath = DOLConfigBridge.shadersDirectoryPath() ?? ""
    if dirPath.isEmpty,
       let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    {
      dirPath = docs.appendingPathComponent("Shaders", isDirectory: true).path
    }
    guard !dirPath.isEmpty else { return nil }
    _ = try? FileManager.default.createDirectory(
      atPath: dirPath, withIntermediateDirectories: true)
    return dirPath
  }
  
  private func downloadRemoteFile(entry: RemoteLibretroEntry) {
    downloadStatus = "Downloading \(entry.name)…"
    
    let encodedPath = entry.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? entry.path
    let rawURLString = "https://raw.githubusercontent.com/libretro/slang-shaders/master/\(encodedPath)"
    guard let url = URL(string: rawURLString) else {
      downloadStatus = "Invalid raw URL."
      return
    }
    guard let baseDir = shadersDirectory() else {
      downloadStatus = "Could not resolve Shaders directory."
      return
    }
    
    // Place under Shaders/libretro/<path>
    let root = URL(fileURLWithPath: baseDir).appendingPathComponent("libretro", isDirectory: true)
    let destURL = root.appendingPathComponent(entry.path)
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
      DispatchQueue.main.async {
        if let error = error {
          downloadStatus = "Download failed: \(error.localizedDescription)"
          return
        }
        guard
          let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode),
          let data = data
        else {
          downloadStatus = "Download failed."
          return
        }
        
        do {
          try FileManager.default.createDirectory(
            at: destURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
          )
          try data.write(to: destURL, options: .atomic)
          downloadStatus = "Saved shader as libretro/\(entry.path)"
        } catch {
          downloadStatus = "Failed to save: \(error.localizedDescription)"
        }
      }
    }
    task.resume()
  }

  private func downloadAllShaders(in files: [RemoteLibretroEntry]) {
    guard !files.isEmpty else {
      downloadStatus = "No shaders to download in this folder."
      return
    }
    downloadStatus = "Downloading \(files.count) shaders…"
    for file in files {
      downloadRemoteFile(entry: file)
    }
  }
}
struct ShaderDownloadView: View {
  @Environment(\.dismiss) private var dismiss
  
  var onComplete: (String) -> Void
  
  @State private var urlString: String = ""
  @State private var isDownloading = false
  @State private var statusMessage: String = ""
  
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Download from URL")) {
          TextField("Paste .glsl/.glslp/.slang/.slangp URL", text: $urlString)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
          
          Button {
            startDownload()
          } label: {
            if isDownloading {
              ProgressView()
            } else {
              Text("Download and Save")
            }
          }
          .disabled(
            isDownloading ||
              urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        
        Section(
          footer: Text(
            "URLs from GitHub raw content are supported, e.g. libretro/slang-shaders or Anime4K single-pass shaders."
          )
        ) {
          if !statusMessage.isEmpty {
            Text(statusMessage)
              .font(.footnote)
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("Download Shader")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }
      }
    }
  }
  
  private func shadersDirectory() -> String? {
    var dirPath = DOLConfigBridge.shadersDirectoryPath() ?? ""
    if dirPath.isEmpty,
       let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    {
      dirPath = docs.appendingPathComponent("Shaders", isDirectory: true).path
    }
    guard !dirPath.isEmpty else { return nil }
    _ = try? FileManager.default.createDirectory(
      atPath: dirPath, withIntermediateDirectories: true)
    return dirPath
  }
  
  private func startDownload() {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed) else {
      statusMessage = "Invalid URL."
      return
    }
    guard let dir = shadersDirectory() else {
      statusMessage = "Could not resolve Shaders directory."
      return
    }
    
    let allowedExts = [".glsl", ".glslp", ".slang", ".slangp"]
    let filename = url.lastPathComponent
    guard allowedExts.contains(where: { filename.lowercased().hasSuffix($0) }) else {
      statusMessage = "URL must end with .glsl, .glslp, .slang, or .slangp."
      return
    }
    
    isDownloading = true
    statusMessage = "Downloading…"
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
      DispatchQueue.main.async {
        self.isDownloading = false
        
        if let error = error {
          self.statusMessage = "Download failed: \(error.localizedDescription)"
          return
        }
        guard
          let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode),
          let data = data
        else {
          self.statusMessage = "Download failed: bad response."
          return
        }
        
        let destURL = URL(fileURLWithPath: dir).appendingPathComponent(filename)
        do {
          try data.write(to: destURL, options: .atomic)
          let msg = "Saved shader as \(filename)"
          self.statusMessage = msg
          self.onComplete(msg)
        } catch {
          self.statusMessage = "Failed to save: \(error.localizedDescription)"
        }
      }
    }
    task.resume()
  }
}

// MARK: - MetalFX Pickers

@available(iOS 16.0, *)
struct MetalFXResolutionPickerView: View {
  @StateObject private var config = ConfigBridge.shared
  
  private let resolutions: [(String, Int, Int)] = [
    ("Native", 0, 0),
    ("1280x720 (720p)", 1280, 720),
    ("1920x1080 (1080p)", 1920, 1080),
    ("2560x1440 (1440p)", 2560, 1440),
    ("3840x2160 (4K)", 3840, 2160),
  ]
  
  var body: some View {
    List {
      ForEach(resolutions, id: \.1) { option in
        Button {
          config.metalFXOutputWidth = option.1
          config.metalFXOutputHeight = option.2
        } label: {
          HStack {
            Text(option.0)
              .foregroundColor(.primary)
            Spacer()
            if config.metalFXOutputWidth == option.1 {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Output Resolution")
  }
}

#if DEBUG
struct VideoSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      VideoSettingsView()
    }
  }
}
#endif
