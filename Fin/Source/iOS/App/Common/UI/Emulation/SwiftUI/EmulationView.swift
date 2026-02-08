// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit
import SwiftUI
import Combine
import Foundation
import UniformTypeIdentifiers

// MARK: - iOS Version Compatibility Modifiers

/// Hides persistent system overlays (home indicator area)
struct HidePersistentOverlaysModifier: ViewModifier {
  func body(content: Content) -> some View {
    content.persistentSystemOverlays(.hidden)
  }
}

/// Hides toolbar background
struct HideToolbarBackgroundModifier: ViewModifier {
  func body(content: Content) -> some View {
    content.toolbarBackground(.hidden, for: .navigationBar)
  }
}

/// Hides list scroll background so list matches panel
struct HideListScrollBackgroundModifier: ViewModifier {
  func body(content: Content) -> some View {
    content.scrollContentBackground(.hidden)
  }
}

// MARK: - Visible Touch Pad Type

enum VisibleTouchPad: Int {
  case none = 0
  case gameCube = 1
  case wiimote = 2
  case sidewaysWiimote = 3
  case classic = 4
}

@MainActor
final class EmulationViewModel: ObservableObject {
  @Published var visibleTouchPad: VisibleTouchPad = .none
  @Published var touchPadOpacity: Float = 1.0
  @Published var isPaused: Bool = false
  @Published var stateSlot: Int = 1
  @Published var isWiiGame: Bool = false
  @Published var showingSkylanderAlert: Bool = false
  @Published var isRewindAvailable: Bool = false   // current checkpoint (slot 10)
  @Published var isRewindLastAvailable: Bool = false  // previous checkpoint (slot 11)
  @Published var rewindEnabled: Bool = true  // from settings; when false, rewind is disabled
  
  // MetalFX settings
  @Published var metalFXUpscaling: Bool = false
  
  // Speed settings
  @Published var emulationSpeed: Float = 1.0
  
  // IR Mode
  @Published var irMode: Int = 0
  
  // Aspect ratio (1 = 16:9, 2 = 4:3, 3 = Fill, 4 = Full)
  @Published var aspectRatio: Int = 2
  
  // Anti-aliasing (1 = Off, 2 = 2x MSAA, 4 = 4x MSAA, etc.)
  @Published var msaa: Int = 1
  
  // SSAA (Super-Sampled Anti-Aliasing) – only applies when MSAA > 1
  @Published var ssaa: Bool = false
  
  // Internal Resolution (EFB scale: 0 = Auto, 1 = 1x, 2 = 2x, etc.)
  @Published var internalResolution: Int = 1
  
  // Output resampling (0 = Default, 1 = Bilinear, etc.)
  @Published var outputResampling: Int = 0
  
  // Post-processing: multiple shaders can be selected; first enabled one is applied to Dolphin
  @Published var postProcessingShader: String = ""
  @Published var postProcessingShaderNames: [String] = ["None"]
  @Published var selectedPostProcessingShaders: Set<String> = []
  
  // CPU core: 0 = Interpreter, 1 = Cached Interpreter, 2 = Inline Cached Interpreter
  @Published var cpuCore: Int = 1
  
  // Widescreen hack (renders game in 16:9 internally; some games need this off)
  @Published var widescreen: Bool = false
  
  // HDR output (when display supports EDR)
  @Published var hdrOutput: Bool = false
  
  // Cheats
  @Published var cheats: [DOLGeckoCode] = []
  @Published var isDownloadingCheats: Bool = false
  
  @Published var requestDismissFromEmulationEnd: Bool = false
  
  /// Boot parameter (EmulationBootParameter from Obj-C, opaque to Swift)
  var bootParameter: AnyObject?
  private var cancellables = Set<AnyCancellable>()
  private var isEmulationRunning: Bool = false
  
  /// Rewind current = slot 10, rewind last = slot 11. Every 15s: copy 10→11, then save to 10.
  private let rewindSlotCurrent: Int32 = 10
  private let rewindSlotLast: Int32 = 11
  private let rewindCaptureInterval: TimeInterval = 15.0
  private var rewindAccumulatedTime: TimeInterval = 0
  private var rewindCaptureInProgress: Bool = false
  private var rewindTimerCancellable: AnyCancellable?
  
  init() {
    loadSettings()
    setupNotifications()
    setupRewindTimer()
  }
  
  /// Cancel all timers, subscriptions, and stop emulation if still running.
  /// Called from EmulationView.onDisappear.
  func cleanup() {
    rewindTimerCancellable?.cancel()
    rewindTimerCancellable = nil
    cancellables.removeAll()
    if isEmulationRunning {
      EmulationCoordinator.shared().requestStop()
    }
  }
  
  func loadSettings() {
    rewindEnabled = DOLConfigBridge.rewindEnabled()
    touchPadOpacity = min(max(DOLConfigBridge.touchPadOpacity(), 0), 1)
    stateSlot = Int(DOLConfigBridge.selectedStateSlot())
    emulationSpeed = DOLConfigBridge.emulationSpeed()
    metalFXUpscaling = DOLConfigBridge.metalFXUpscaling()
    irMode = Int(DOLConfigBridge.touchPadIRMode())
    // UI aspect ratio is stored separately; Dolphin always gets Stretch (3).
    let savedUIAspect = UserDefaults.standard.integer(forKey: "DOLUIAspectRatio")
    aspectRatio = (savedUIAspect >= 1 && savedUIAspect <= 4) ? savedUIAspect : 3
    DOLConfigBridge.setAspectRatioLive(Int32(3))
    DOLConfigBridge.setAspectRatio(Int32(3))
    cpuCore = Int(DOLConfigBridge.cpuCore())
    widescreen = DOLConfigBridge.widescreen()
    msaa = Int(DOLConfigBridge.msaa())
    ssaa = DOLConfigBridge.ssaa()
    internalResolution = Int(DOLConfigBridge.internalResolution())
    outputResampling = Int(DOLConfigBridge.outputResampling())
    postProcessingShader = DOLConfigBridge.postProcessingShader() ?? ""
    let savedShaders = UserDefaults.standard.stringArray(forKey: "DOLSelectedPostProcessingShaders") ?? []
    selectedPostProcessingShaders = Set(savedShaders)
    // If there's an active shader not in the saved set, add it
    if !postProcessingShader.isEmpty && !selectedPostProcessingShaders.contains(postProcessingShader) {
      selectedPostProcessingShaders.insert(postProcessingShader)
    }
    hdrOutput = DOLConfigBridge.hdrOutput()
    refreshPostProcessingShaderList()
  }

  private func setupNotifications() {
    NotificationCenter.default.publisher(for: NSNotification.Name("DOLHostTitleChangedNotification"))
      .sink { [weak self] _ in
        Task { @MainActor in self?.handleTitleChanged() }
      }
      .store(in: &cancellables)
    
    NotificationCenter.default.publisher(for: NSNotification.Name("DOLEmulationDidEndNotification"))
      .sink { [weak self] _ in
        Task { @MainActor in self?.handleEmulationEnd() }
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: NSNotification.Name("DOLEmulationDidStartNotification"))
      .sink { [weak self] _ in
        Task { @MainActor in self?.handleEmulationStart() }
      }
      .store(in: &cancellables)
  }
  
  private func setupRewindTimer() {
    rewindTimerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.rewindTimerTick()
      }
  }
  
  private func rewindTimerTick() {
    guard DOLConfigBridge.rewindEnabled(), isEmulationRunning, !isPaused else {
      return
    }
    guard !rewindCaptureInProgress else { return }
    rewindAccumulatedTime += 1.0
    guard rewindAccumulatedTime >= rewindCaptureInterval else { return }
    rewindAccumulatedTime = 0
    if isRewindAvailable {
      rewindCaptureInProgress = true
      let current = rewindSlotCurrent
      let last = rewindSlotLast
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        EmulationCoordinator.shared().copyState(fromSlot: current, toSlot: last)
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.isRewindLastAvailable = true
          EmulationCoordinator.shared().saveState(self.rewindSlotCurrent)
          self.isRewindAvailable = true
          self.rewindCaptureInProgress = false
        }
      }
    } else {
      EmulationCoordinator.shared().saveState(rewindSlotCurrent)
      isRewindAvailable = true
    }
  }
  
  func handleTitleChanged() {
    isRewindAvailable = false
    isRewindLastAvailable = false
    rewindAccumulatedTime = 0
    rewindCaptureInProgress = false
    isWiiGame = EmulationCoordinator.shared().isWiiGame
    if isWiiGame {
      updateVisibleTouchPadToWii()
    } else {
      updateVisibleTouchPadToGameCube()
    }
    
    // Load cheats for current game
    loadCheats()
  }
  
  func handleEmulationEnd() {
    isEmulationRunning = false
    isRewindAvailable = false
    isRewindLastAvailable = false
    rewindAccumulatedTime = 0
    rewindCaptureInProgress = false
    cheats = []
    if !EmulationCoordinator.shared().isExternalDisplayConnected {
      EmulationCoordinator.shared().clearMetalLayer()
    }
    requestDismissFromEmulationEnd = true
  }
  
  private func handleEmulationStart() {
    isEmulationRunning = true
    isRewindAvailable = false
    isRewindLastAvailable = false
    rewindAccumulatedTime = 0
    // Ensure touch controls are shown as soon as emulation starts,
    // even if the title-changed notification hasn't fired yet.
    isWiiGame = EmulationCoordinator.shared().isWiiGame
    if isWiiGame {
      updateVisibleTouchPadToWii()
    } else {
      updateVisibleTouchPadToGameCube()
    }
  }

  func updateVisibleTouchPadToWii() {
    // Show a Wiimote-style touch pad for Wii games
    let extensionType = EmulationCoordinator.shared().activeWiimoteExtension
    let isSideways = EmulationCoordinator.shared().isWiimoteSideways

    if extensionType == 1 { // Classic
      visibleTouchPad = .classic
    } else if isSideways {
      visibleTouchPad = .sidewaysWiimote
    } else {
      visibleTouchPad = .wiimote
    }
  }
  
  func updateVisibleTouchPadToGameCube() {
    // Show GameCube touch pad
    visibleTouchPad = .gameCube
  }

  /// Call on appear so the overlay is correct if the start notification was missed or after returning from menu.
  func refreshVisibleTouchPadIfNeeded() {
    isWiiGame = EmulationCoordinator.shared().isWiiGame
    if isWiiGame {
      updateVisibleTouchPadToWii()
    } else {
      updateVisibleTouchPadToGameCube()
    }
  }
  
  var isWiimoteTouchPadAttached: Bool {
    EmulationCoordinator.shared().isWiimoteTouchPadAttached
  }
  
  var isGameCubeTouchPadAttached: Bool {
    EmulationCoordinator.shared().isGameCubeTouchPadAttached
  }
  
  var emulateSkylanderPortal: Bool {
    DOLConfigBridge.emulateSkylanderPortal()
  }
  
  // MARK: - Actions
  
  func stopEmulation() {
    performStop()
  }
  
  func performStop() {
    EmulationCoordinator.shared().requestStop()
  }
  
  func togglePause() {
    isPaused.toggle()
    EmulationCoordinator.shared().userRequestedPause = isPaused
  }
  
  func loadState() {
    EmulationCoordinator.shared().loadState(Int32(stateSlot))
  }
  
  func saveState() {
    EmulationCoordinator.shared().saveState(Int32(stateSlot))
  }
  
  func setStateSlot(_ slot: Int) {
    stateSlot = slot
    DOLConfigBridge.setSelectedStateSlot(Int32(slot))
  }
  
  /// Rewind to current checkpoint (slot 10). Resets the 15s timer.
  func triggerRewindCurrent() {
    guard DOLConfigBridge.rewindEnabled(), isRewindAvailable else { return }
    EmulationCoordinator.shared().loadState(rewindSlotCurrent)
    rewindAccumulatedTime = 0
  }

  /// Rewind to previous checkpoint (slot 11). Resets the 15s timer.
  func triggerRewindLast() {
    guard DOLConfigBridge.rewindEnabled(), isRewindLastAvailable else { return }
    EmulationCoordinator.shared().loadState(rewindSlotLast)
    rewindAccumulatedTime = 0
  }
  
  // MARK: - Cheats
  
  func loadCheats() {
    DOLGeckoBridge.loadCodesForCurrentGame()
    cheats = DOLGeckoBridge.codes()
  }
  
  func setCheatEnabled(_ enabled: Bool, at index: Int) {
    guard index >= 0 && index < cheats.count else { return }
    DOLGeckoBridge.setEnabled(enabled, forCodeAt: index)
    cheats[index].enabled = enabled
  }
  
  func downloadCheats() {
    isDownloadingCheats = true
    DOLGeckoBridge.downloadCodes { [weak self] success, _, _, _ in
      Task { @MainActor in
        guard let self = self else { return }
        self.isDownloadingCheats = false
        if success {
          self.loadCheats()
        }
      }
    }
  }
  
  func setEmulationSpeed(_ speed: Float) {
    emulationSpeed = speed
    DOLConfigBridge.setEmulationSpeed(speed)
  }
  
  func setMetalFXUpscaling(_ enabled: Bool) {
    metalFXUpscaling = enabled
    DOLConfigBridge.setMetalFXUpscaling(enabled)
    // MetalFX should output HDR when enabled
    if enabled && !hdrOutput {
      setHdrOutput(true)
    }
    EmulationCoordinator.shared().notifySurfaceResizeForced()
  }
  
  func setIRMode(_ mode: Int) {
    irMode = mode
    DOLConfigBridge.setTouchPadIRMode(Int32(mode))
  }
  
  func setAspectRatio(_ ratio: Int) {
    guard [1, 2, 3, 4].contains(ratio) else { return }
    if aspectRatio != ratio {
      aspectRatio = ratio
      UserDefaults.standard.set(ratio, forKey: "DOLUIAspectRatio")
      // Always tell Dolphin to Stretch – we control the frame size from SwiftUI.
      DOLConfigBridge.setAspectRatioLive(Int32(3))
      DOLConfigBridge.setAspectRatio(Int32(3))
      EmulationCoordinator.shared().notifySurfaceResizeForced()
    }
  }
  
  var aspectRatioDisplayString: String {
    switch aspectRatio {
    case 0: return "Auto"
    case 1: return "Force 16:9"
    case 2: return "Force 4:3"
    case 3: return "Stretch"
    case 4: return "Custom"
    case 5: return "Custom Stretch"
    case 6: return "Raw"
    default: return "Auto"
    }
  }
  
  func setMsaa(_ samples: Int) {
    msaa = samples
    DOLConfigBridge.setMsaaLive(Int32(samples))
    DOLConfigBridge.setMsaa(Int32(samples))
    EmulationCoordinator.shared().notifySurfaceResizeForced()
  }
  
  func setSsaa(_ enabled: Bool) {
    ssaa = enabled
    DOLConfigBridge.setSsaa(enabled)
    EmulationCoordinator.shared().notifySurfaceResizeForced()
  }
  
  func setCpuCore(_ value: Int) {
    cpuCore = value
    DOLConfigBridge.setCpuCore(Int32(value))
  }
  
  func setWidescreen(_ enabled: Bool) {
    widescreen = enabled
    DOLConfigBridge.setWidescreen(enabled)
    EmulationCoordinator.shared().notifySurfaceResizeForced()
  }
  
  var msaaDisplayString: String {
    MSAAOptions.label(for: msaa)
  }
  
  // MARK: - Internal Resolution
  
  func setInternalResolution(_ scale: Int) {
    if internalResolution != scale {
      internalResolution = scale
      DOLConfigBridge.setInternalResolutionLive(Int32(scale))
      DOLConfigBridge.setInternalResolution(Int32(scale))
      EmulationCoordinator.shared().notifySurfaceResizeForced()
    }
  }
  
  var internalResolutionDisplayString: String {
    if internalResolution == 0 {
      return "Auto"
    }
    return "\(internalResolution)x"
  }
  
  func setOutputResampling(_ value: Int) {
    outputResampling = value
    DOLConfigBridge.setOutputResampling(Int32(value))
  }
  
  var outputResamplingDisplayString: String {
    switch outputResampling {
    case 0: return "Default"
    case 1: return "Bilinear"
    case 2: return "BSpline"
    case 3: return "Mitchell-Netravali"
    case 4: return "Catmull-Rom"
    case 5: return "Sharp Bilinear"
    case 6: return "Area"
    default: return "Default"
    }
  }
  
  func setPostProcessingShader(_ name: String) {
    let value = name.isEmpty ? "" : name
    if postProcessingShader != value {
      postProcessingShader = value
      DOLConfigBridge.setPostProcessingShader(value.isEmpty ? "" : value)
      EmulationCoordinator.shared().notifySurfaceResize()
    }
  }
  
  /// Toggle a shader on/off in the multi-select set. The first enabled shader (in list order) is applied to Dolphin.
  func togglePostProcessingShader(_ name: String) {
    if selectedPostProcessingShaders.contains(name) {
      selectedPostProcessingShaders.remove(name)
    } else {
      selectedPostProcessingShaders.insert(name)
    }
    UserDefaults.standard.set(Array(selectedPostProcessingShaders), forKey: "DOLSelectedPostProcessingShaders")
    applyFirstSelectedShader()
  }
  
  /// Apply the first selected shader (in postProcessingShaderNames order) to Dolphin's config.
  func applyFirstSelectedShader() {
    let activeShader = postProcessingShaderNames
      .filter { $0 != "None" }
      .first { selectedPostProcessingShaders.contains($0) } ?? ""
    setPostProcessingShader(activeShader)
  }
  
  func setHdrOutput(_ enabled: Bool) {
    if hdrOutput != enabled {
      hdrOutput = enabled
      DOLConfigBridge.setHdrOutput(enabled)
      EmulationCoordinator.shared().notifySurfaceResizeForced()
    }
  }
  
  /// Refreshes postProcessingShaderNames from the Shaders directory (I/O on background queue).
  func refreshPostProcessingShaderList() {
    var dirPath = DOLConfigBridge.shadersDirectoryPath()
    if dirPath.isEmpty {
      let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      if let shaders = docs?.appendingPathComponent("Shaders", isDirectory: true) {
        dirPath = shaders.path
      }
    }
    guard !dirPath.isEmpty else {
      postProcessingShaderNames = ["None"]
      return
    }
    let path = dirPath
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      _ = try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
      var nameSet: Set<String> = []
      let allowedSuffixes = [".glsl", ".glslp", ".slang", ".slangp"]
      if let enumerator = FileManager.default.enumerator(atPath: path) {
        while let file = enumerator.nextObject() as? String {
          guard !file.hasPrefix(".") else { continue }
          let hasAllowedSuffix = allowedSuffixes.contains { file.hasSuffix($0) }
          guard hasAllowedSuffix else { continue }
          let name = (file as NSString).lastPathComponent
          let baseName = (name as NSString).deletingPathExtension
          if !baseName.isEmpty && baseName != "default_pre_post_process" {
            nameSet.insert(baseName)
          }
        }
      }
      var names = Array(nameSet)
      names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
      let result = ["None"] + names
      DispatchQueue.main.async {
        self?.postProcessingShaderNames = result
      }
    }
  }

  /// Copy a shader file (e.g. from Files app) into the Shaders directory and refresh the list.
  func importShader(from sourceURL: URL) {
    let allowedSuffixes = [".glsl", ".glslp", ".slang", ".slangp"]
    let name = sourceURL.lastPathComponent
    guard allowedSuffixes.contains(where: { name.lowercased().hasSuffix($0) }) else { return }
    var dirPath: String? = DOLConfigBridge.shadersDirectoryPath()
    if let d = dirPath, d.isEmpty { dirPath = nil }
    if dirPath == nil {
      if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let shaders = docs.appendingPathComponent("Shaders", isDirectory: true)
        dirPath = shaders.path
      }
    }
    guard let path = dirPath else { return }
    let destURL = URL(fileURLWithPath: path).appendingPathComponent(name)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      _ = try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
      let needsAccess = sourceURL.startAccessingSecurityScopedResource()
      defer { if needsAccess { sourceURL.stopAccessingSecurityScopedResource() } }
      do {
        if FileManager.default.fileExists(atPath: destURL.path) {
          try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        DispatchQueue.main.async { self?.refreshPostProcessingShaderList() }
      } catch { }
    }
  }

  var speedDisplayString: String {
    if emulationSpeed == 0 {
      return "Unlimited"
    }
    if emulationSpeed == Float(Int(emulationSpeed)) {
      return "\(Int(emulationSpeed))x"
    }
    return String(format: "%.1fx", emulationSpeed)
  }
}

private enum GameMenuPanel: String, CaseIterable, Identifiable {
  case controller
  case gameOptions
  case resolution
  case msaa
  case postProcessing
  case outputResampling
  case speed
  case slot
  var id: String { rawValue }
}

/// Auto-hide / auto-opacity for floating buttons after 5 seconds.
private enum AutoHideBarOption: String, CaseIterable, Identifiable {
  case off
  case hide
  case clear
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .off: return "Off"
    case .hide: return "Hide"
    case .clear: return "Clear"
    }
  }
}

private let kAutoHideDelay: TimeInterval = 5.0
private let kFadedOpacity: Double = 0.04   // 96% transparent, still tappable

struct EmulationView: View {
  @StateObject private var viewModel = EmulationViewModel()
  @State private var showingEmulationMenu = false
  @State private var menuExpanded = false
  @State private var didPauseForMenu = false
  @State private var openPanels: [GameMenuPanel] = []
  @State private var preferredTouch: Bool = true
  @State private var currentInputDeviceName: String = "Touch"
  @State private var touchControlStyle: TouchControlStyle = TouchControlStyleSetting.current()
  @State private var pauseWhenInMenu: Bool = false
  @State private var keepSubmenusOpen: Bool = false
  @State private var preventScreenSleep: Bool = false
  @State private var useSafeCoreForCurrentGame: Bool = false

  @State private var autoHideBarOption: AutoHideBarOption = .off
  @State private var buttonsOpacity: Double = 1.0
  @State private var lastButtonInteractionTime: Date = Date()
  @State private var showShaderImporter: Bool = false
  @State private var editingLayout: Bool = false

  let bootParameter: AnyObject?

  /// Whether the current orientation is landscape.
  private var isCurrentlyLandscape: Bool {
    UIScreen.main.bounds.width > UIScreen.main.bounds.height
  }

  /// Physical screen dimensions in the current orientation.
  private var screenSize: (w: CGFloat, h: CGFloat) {
    (UIScreen.main.bounds.width, UIScreen.main.bounds.height)
  }

  /// Computes renderer frame size based on orientation and aspect ratio.
  /// Dolphin always gets Stretch – we control the frame size here.
  private func rendererSize() -> (width: CGFloat, height: CGFloat) {
    let (sw, sh) = screenSize

    if isCurrentlyLandscape {
      switch viewModel.aspectRatio {
      case 1: // 16:9
        let gameW = min(sh * 16.0 / 9.0, sw)
        return (gameW, sh)
      case 2: // 4:3
        let gameW = min(sh * 4.0 / 3.0, sw)
        return (gameW, sh)
      default: // Full (4) – fill entire physical screen
        return (sw, sh)
      }
    }

    // Portrait
    switch viewModel.aspectRatio {
    case 1: // 16:9 at top
      let gameH = sw * 9.0 / 16.0
      return (sw, gameH)
    case 3: // Fill – top down to where controls begin
      let gameH = sh * 0.55
      return (sw, gameH)
    case 4: // Full – entire physical screen
      return (sw, sh)
    default:
      let gameH = sh * 0.55
      return (sw, gameH)
    }
  }

  var body: some View {
    GeometryReader { geometry in
      let globalFrame = geometry.frame(in: .global)
      let (sw, sh) = screenSize
      let renderer = rendererSize()
      let isFullScreen = isCurrentlyLandscape || viewModel.aspectRatio == 4

      ZStack(alignment: .topLeading) {
        Color.black

        RendererContainerView()
          .frame(width: renderer.width, height: renderer.height)
          .position(
            x: sw / 2,
            y: isFullScreen ? sh / 2 : renderer.height / 2
          )

        touchControllerOverlay
          .frame(width: sw, height: sh)
          .contentShape(Rectangle())
          .opacity(Double(min(max(viewModel.touchPadOpacity, 0), 1)))
          .allowsHitTesting(viewModel.visibleTouchPad != .none)
      }
      .frame(width: sw, height: sh)
      .offset(x: -globalFrame.origin.x, y: -globalFrame.origin.y)
      .onChange(of: geometry.size) { _ in
        applyAspectRatioForOrientation(landscape: isCurrentlyLandscape)
      }
    }
    .ignoresSafeArea()
    .statusBarHidden()
    .modifier(HidePersistentOverlaysModifier())
    .overlay(alignment: .top) {
      floatingTopButtons
        .opacity(buttonsOpacity)
        .animation(.easeInOut(duration: 0.3), value: buttonsOpacity)
    }
    .overlay(alignment: .top) {
      // Generous invisible tap strip at the top to restore hidden buttons
      Color.clear
        .frame(height: 80)
        .contentShape(Rectangle())
        .onTapGesture { restoreButtons() }
        .allowsHitTesting(buttonsOpacity < 1)
    }
    .overlay {
      if showingEmulationMenu {
        gameMenuOverlay()
      }
    }
    .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
      checkAutoHide()
    }
    .onChange(of: showingEmulationMenu) { isOpen in
      if isOpen {
        preferredTouch = PreferredInput.preferredInputIsTouch()
        currentInputDeviceName = preferredTouch ? "Touch" : controllerDisplayNameForPort0()
        useSafeCoreForCurrentGame = SafeCoreGameIDsStorage.contains(DOLGeckoBridge.currentGameId() ?? "")
      } else {
        if !keepSubmenusOpen {
          openPanels = []
        }
        if didPauseForMenu {
          viewModel.isPaused = false
          EmulationCoordinator.shared().userRequestedPause = false
          didPauseForMenu = false
        }
      }
    }
    .onAppear {
      viewModel.bootParameter = bootParameter
      viewModel.loadSettings()
      PreferredInput.ensureDefaultPreferredInputIfNeeded()
      PreferredInput.applyPreferredInput()
      preferredTouch = PreferredInput.preferredInputIsTouch()
      currentInputDeviceName = preferredTouch ? "Touch" : controllerDisplayNameForPort0()
      touchControlStyle = TouchControlStyleSetting.current()
      startEmulationIfNeeded()
      viewModel.refreshVisibleTouchPadIfNeeded()
      if let raw = UserDefaults.standard.string(forKey: "DOLAutoHideBarOption"),
         let option = AutoHideBarOption(rawValue: raw) {
        autoHideBarOption = option
      }
      preventScreenSleep = UserDefaults.standard.bool(forKey: "DOLPreventScreenSleep")
      UIApplication.shared.isIdleTimerDisabled = preventScreenSleep
      // Apply initial aspect ratio based on current orientation
      let landscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
      applyAspectRatioForOrientation(landscape: landscape)
    }
    .onReceive(NotificationCenter.default.publisher(for: .DOLTouchControlStyleChanged)) { _ in
      touchControlStyle = TouchControlStyleSetting.current()
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      if editingLayout {
        editingLayout = false
        TCLayoutManager.shared.setEditMode(false)
      }
      // Stop emulation and clean up all resources when leaving the emulation screen
      viewModel.cleanup()
    }
    .onChange(of: viewModel.requestDismissFromEmulationEnd) { shouldDismiss in
      if shouldDismiss {
        viewModel.requestDismissFromEmulationEnd = false
        NotificationCenter.default.post(name: NSNotification.Name("DOLDismissEmulationView"), object: nil)
      }
    }
    .fileImporter(
      isPresented: $showShaderImporter,
      allowedContentTypes: [.data, .plainText, .content],
      allowsMultipleSelection: false
    ) { result in
      guard case .success(let urls) = result, let url = urls.first else { return }
      viewModel.importShader(from: url)
    }
  }
  
  // MARK: - Floating top buttons (no bar) + auto-hide / auto-opacity

  private var floatingTopButtons: some View {
    GeometryReader { geo in
      HStack {
        // Settings: capsule on iOS 26 (like before), circle otherwise
        Button(action: {
          recordButtonInteraction()
          openGameMenu()
        }) {
          Image(systemName: "gearshape")
            .font(.title2)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .background(settingsBubbleBackground)

        Spacer(minLength: 0)

        // One glass bubble for rewind (current), rewind (last) when enabled, play/pause, stop
        HStack(spacing: 6) {
          if viewModel.rewindEnabled {
            Button(action: {
              recordButtonInteraction()
              viewModel.triggerRewindCurrent()
            }) {
              Image(systemName: "gobackward")
                .font(.title2)
                .foregroundStyle(.white)
            }
            .disabled(!viewModel.isRewindAvailable)
            .opacity(rewindButtonOpacity(available: viewModel.isRewindAvailable))
            .accessibilityLabel("Rewind to current checkpoint")
            .frame(width: 40, height: 40)

            Button(action: {
              recordButtonInteraction()
              viewModel.triggerRewindLast()
            }) {
              Image(systemName: "gobackward.circle")
                .font(.title2)
                .foregroundStyle(.white)
            }
            .disabled(!viewModel.isRewindLastAvailable)
            .opacity(rewindButtonOpacity(available: viewModel.isRewindLastAvailable))
            .accessibilityLabel("Rewind to previous checkpoint")
            .frame(width: 40, height: 40)
          }

          Button(action: {
            recordButtonInteraction()
            viewModel.togglePause()
          }) {
            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
              .font(.title2)
              .foregroundStyle(.white)
          }
          .frame(width: 40, height: 40)

          Button(action: {
            recordButtonInteraction()
            viewModel.stopEmulation()
          }) {
            Image(systemName: "stop.fill")
              .font(.title2)
              .foregroundStyle(.white)
          }
          .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
      }
      .padding(.horizontal, 16)
      .padding(.top, geo.safeAreaInsets.top + 8)
      .padding(.bottom, 8)
      .allowsHitTesting(buttonsOpacity == 1)
    }
  }

  /// Settings bubble: capsule (old style) on iOS 26+.
  @ViewBuilder
  private var settingsBubbleBackground: some View {
    Capsule().fill(.ultraThinMaterial).opacity(0.8)
  }

  private func recordButtonInteraction() {
    lastButtonInteractionTime = Date()
    if buttonsOpacity < 1 { restoreButtons() }
  }

  private func checkAutoHide() {
    guard autoHideBarOption != .off else { return }
    guard !showingEmulationMenu else { return }
    guard buttonsOpacity >= 1 else { return }
    guard Date().timeIntervalSince(lastButtonInteractionTime) >= kAutoHideDelay else { return }
    withAnimation(.easeInOut(duration: 0.3)) {
      switch autoHideBarOption {
      case .off: break
      case .hide:
        buttonsOpacity = 0
      case .clear:
        buttonsOpacity = kFadedOpacity
      }
    }
  }

  private func restoreButtons() {
    lastButtonInteractionTime = Date()
    withAnimation(.easeInOut(duration: 0.3)) {
      buttonsOpacity = 1
    }
  }

  /// Reapplies the current aspect ratio to the Dolphin core and triggers a resize.
  /// Also auto-corrects invalid aspect ratios for the new orientation.
  private func applyAspectRatioForOrientation(landscape: Bool) {
    // 4:3 (2) is landscape-only; Fill (3) is portrait-only
    if landscape && viewModel.aspectRatio == 3 {
      viewModel.setAspectRatio(1) // Fill → 16:9 in landscape
    } else if !landscape && viewModel.aspectRatio == 2 {
      viewModel.setAspectRatio(1) // 4:3 → 16:9 in portrait
    }
    // Always tell Dolphin to Stretch – we control the frame size from SwiftUI.
    DOLConfigBridge.setAspectRatioLive(Int32(3))
    DOLConfigBridge.setAspectRatio(Int32(3))
    EmulationCoordinator.shared().notifySurfaceResizeForced()
  }

  /// In clear mode, rewind (when available) stays visible (0.9); otherwise full or dim by availability.
  private func rewindButtonOpacity(available: Bool) -> Double {
    if autoHideBarOption == .clear, available { return 0.9 }
    return available ? 1 : 0.6
  }

  // MARK: - Game menu overlay

  /// Overlay: dimmed background + menu card at top-leading.
  @ViewBuilder
  private func gameMenuOverlay() -> some View {
    GeometryReader { geo in
      ZStack(alignment: .topLeading) {
        Color.clear
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture(perform: dismissGameMenu)
        gameMenuPopoverContent()
          .padding(.top, geo.safeAreaInsets.top + 8)
          .padding(.leading, 12)
      }
    }
    .transition(.opacity)
  }

  // MARK: - Game Menu (popout, pause while open)
  
  private func openGameMenu() {
    menuExpanded = false
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
      showingEmulationMenu = true
    }
    pauseWhenInMenu = DOLConfigBridge.pauseWhenInMenu()
    keepSubmenusOpen = UserDefaults.standard.bool(forKey: "DOLKeepSubmenusOpen")
    preventScreenSleep = UserDefaults.standard.bool(forKey: "DOLPreventScreenSleep")
    if let raw = UserDefaults.standard.string(forKey: "DOLAutoHideBarOption"),
       let option = AutoHideBarOption(rawValue: raw) {
      autoHideBarOption = option
    }
    if DOLConfigBridge.pauseWhenInMenu() {
      viewModel.isPaused = true
      EmulationCoordinator.shared().userRequestedPause = true
      didPauseForMenu = true
    } else {
      didPauseForMenu = false
    }
    // Defer loadSettings so the menu opens immediately without blocking the tap handler.
    DispatchQueue.main.async {
      viewModel.loadSettings()
    }
  }
  
  private func dismissGameMenu() {
    guard showingEmulationMenu else { return }
    withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
      showingEmulationMenu = false
    }
    if !keepSubmenusOpen {
      openPanels = []
    }
    if didPauseForMenu {
      viewModel.isPaused = false
      EmulationCoordinator.shared().userRequestedPause = false
      didPauseForMenu = false
    }
    // Defer config work to next run loop so native code isn't run inside the gesture path (avoids SIGSEGV).
    DispatchQueue.main.async {
      ConfigBridge.shared.reload()
      DOLConfigBridge.saveConfig()
    }
  }
  
  /// Display name for port 0 when using a physical controller (for menu label).
  private func controllerDisplayNameForPort0() -> String {
    let type: DOLMappingType = viewModel.isWiiGame ? .wiimote : .pad
    DOLMappingBridge.initialize(for: type, port: 0)
    let dev = DOLMappingBridge.defaultDevice() ?? ""
    if dev.isEmpty { return "Controller" }
    let parts = dev.components(separatedBy: "/")
    if parts.count >= 3 { return parts[2].trimmingCharacters(in: .whitespaces) }
    return dev
  }

  private func setPreferredInputTouch(_ useTouch: Bool) {
    preferredTouch = useTouch
    PreferredInput.setPreferredInputTouch(useTouch)
    currentInputDeviceName = useTouch ? "Touch" : controllerDisplayNameForPort0()
    if viewModel.isWiiGame {
      viewModel.updateVisibleTouchPadToWii()
    } else {
      viewModel.updateVisibleTouchPadToGameCube()
    }
  }

  private func togglePanel(_ panel: GameMenuPanel) {
    withAnimation(.easeInOut(duration: 0.2)) {
      if let idx = openPanels.firstIndex(of: panel) {
        openPanels.remove(at: idx)
      } else {
        openPanels.append(panel)
      }
    }
  }
  
  private func closePanel(_ panel: GameMenuPanel) {
    withAnimation(.easeInOut(duration: 0.2)) {
      openPanels.removeAll { $0 == panel }
    }
  }
  
  /// Menu font size scaled by device width so text fits; use for all menu text.
  private static func menuFontSize(caption: Bool = false) -> CGFloat {
    let w = UIScreen.main.bounds.width
    if w <= 320 { return caption ? 9 : 10 }
    if w <= 390 { return caption ? 10 : 11 }
    return caption ? 11 : 12
  }
  
  /// Menu card content for popover (presented from the bar / gear location).
  @ViewBuilder
  private func gameMenuPopoverContent() -> some View {
    let mainWidth: CGFloat = 220
    let panelWidth: CGFloat = 140
    let panelCount = openPanels.count
    let totalWidth = mainWidth + CGFloat(panelCount) * panelWidth
    let usePanelScroll = panelCount > 0 && totalWidth > 320

    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center, spacing: 0) {
        gameMenuHeaderCell(mainWidth: mainWidth)
        if usePanelScroll {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 0) {
              ForEach(Array(openPanels.enumerated()), id: \.element.id) { _, panel in
                gameMenuPanelHeaderCell(panel, panelWidth: panelWidth)
              }
            }
          }
        } else {
          ForEach(Array(openPanels.enumerated()), id: \.element.id) { _, panel in
            gameMenuPanelHeaderCell(panel, panelWidth: panelWidth)
          }
        }
      }
      .frame(height: 44)
      .frame(maxWidth: .infinity)

      HStack(alignment: .top, spacing: 0) {
        mainMenuColumnContent(mainWidth: mainWidth)
          .frame(width: mainWidth)
        if usePanelScroll {
          ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
              ForEach(Array(openPanels.enumerated()), id: \.element.id) { _, panel in
                gameMenuSidePanelContent(panel, panelWidth: panelWidth)
                  .frame(width: panelWidth)
              }
            }
          }
        } else {
          ForEach(Array(openPanels.enumerated()), id: \.element.id) { _, panel in
            gameMenuSidePanelContent(panel, panelWidth: panelWidth)
              .frame(width: panelWidth)
          }
        }
      }
    }
    .frame(width: totalWidth, alignment: .topLeading)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
    )
    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 10)
    .frame(minWidth: 280, minHeight: 400, maxHeight: min(500, UIScreen.main.bounds.height * 0.65))
    .scaleEffect(menuExpanded ? 1 : 0.4, anchor: .top)
    .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: menuExpanded)
    .onAppear {
      menuExpanded = true
      viewModel.loadSettings()
    }
  }
  
  private func gameMenuHeaderCell(mainWidth: CGFloat) -> some View {
    let bodyFont = Self.menuFontSize(caption: false)
    return HStack {
      Text("Menu")
        .font(.system(size: bodyFont + 2, weight: .semibold))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(width: mainWidth)
    .padding(.horizontal, 12)
  }
  
  private func gameMenuPanelHeaderCell(_ panel: GameMenuPanel, panelWidth: CGFloat) -> some View {
    let capFont = Self.menuFontSize(caption: true)
    return Button(action: { closePanel(panel) }) {
      HStack {
        Text(panelTitle(panel))
          .font(.system(size: capFont + 1, weight: .semibold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
        Spacer()
      }
      .frame(width: panelWidth)
      .padding(.horizontal, 10)
    }
    .buttonStyle(.plain)
  }
  
  private func mainMenuColumnContent(mainWidth: CGFloat) -> some View {
    let bodyFont = Self.menuFontSize(caption: false)
    let capFont = Self.menuFontSize(caption: true)
    return ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: 10) {
          gameMenuSectionHeader("General", fontSize: max(8, capFont - 2))
          VStack(spacing: 2) {
            Toggle(isOn: Binding(
              get: { pauseWhenInMenu },
              set: { newValue in
                pauseWhenInMenu = newValue
                DOLConfigBridge.setPauseWhenInMenu(newValue)
              }
            )) {
              Label("Pause When in Menu", systemImage: "pause.rectangle")
                .font(.system(size: max(9, bodyFont - 2)))
                .foregroundStyle(.secondary)
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            gameMenuDivider
            Toggle(isOn: Binding(
              get: { keepSubmenusOpen },
              set: {
                keepSubmenusOpen = $0
                UserDefaults.standard.set($0, forKey: "DOLKeepSubmenusOpen")
              }
            )) {
              Label("Keep Submenus Open", systemImage: "rectangle.stack")
                .font(.system(size: max(9, bodyFont - 2)))
                .foregroundStyle(.secondary)
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            gameMenuDivider
            Toggle(isOn: Binding(
              get: { preventScreenSleep },
              set: {
                preventScreenSleep = $0
                UserDefaults.standard.set($0, forKey: "DOLPreventScreenSleep")
                UIApplication.shared.isIdleTimerDisabled = $0
              }
            )) {
              Label("Prevent Screen Sleep", systemImage: "sun.max")
                .font(.system(size: max(9, bodyFont - 2)))
                .foregroundStyle(.secondary)
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            gameMenuDivider
            Toggle(isOn: Binding(
              get: { viewModel.rewindEnabled },
              set: {
                DOLConfigBridge.setRewindEnabled($0)
                viewModel.rewindEnabled = $0
              }
            )) {
              Label("Enable Rewind", systemImage: "gobackward")
                .font(.system(size: max(9, bodyFont - 2)))
                .foregroundStyle(.secondary)
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            gameMenuDivider
            HStack {
              Text("Auto-hide bar (5s)")
                .font(.system(size: max(9, bodyFont - 2)))
                .foregroundStyle(.secondary)
              Spacer()
              Picker("", selection: Binding(
                get: { autoHideBarOption },
                set: {
                  autoHideBarOption = $0
                  UserDefaults.standard.set($0.rawValue, forKey: "DOLAutoHideBarOption")
                }
              )) {
                ForEach(AutoHideBarOption.allCases) { option in
                  Text(option.displayName).tag(option)
                }
              }
              .labelsHidden()
              .pickerStyle(.menu)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
          }
          .padding(6)
          .background(menuRowBubble)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          
          gameMenuSectionHeader("Input", fontSize: capFont)
          VStack(spacing: 0) {
            gameMenuRowWithPanel(title: "Controller", icon: "gamecontroller", value: currentInputDeviceName, panel: .controller, bodyFont: bodyFont)
            gameMenuDivider
            gameMenuEditLayoutRow(bodyFont: bodyFont)
          }
          .padding(8)
          .background(menuRowBubble)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          
          gameMenuSectionHeader("Display", fontSize: capFont)
          VStack(spacing: 4) {
            gameMenuAspectRow(bodyFont: bodyFont)
            gameMenuDivider
            gameMenuWidescreenRow(bodyFont: bodyFont)
            gameMenuDivider
            gameMenuRowWithPanel(title: "Resolution", icon: "square.resize", value: viewModel.internalResolutionDisplayString, panel: .resolution, bodyFont: bodyFont)
            gameMenuDivider
            gameMenuRowWithPanel(title: "MSAA", icon: "circle.hexagongrid", value: viewModel.msaaDisplayString, panel: .msaa, bodyFont: bodyFont)
            gameMenuDivider
            gameMenuSSAARow(bodyFont: bodyFont)
            gameMenuDivider
            gameMenuMetalFXRow(bodyFont: bodyFont)
            // gameMenuDivider
            // gameMenuRowWithPanel(title: "Post-Processing", icon: "wand.and.stars", value: viewModel.postProcessingShader.isEmpty ? "None" : viewModel.postProcessingShader, panel: .postProcessing, bodyFont: bodyFont)
            gameMenuDivider
            gameMenuHDRRow(bodyFont: bodyFont)
            gameMenuDivider
            gameMenuRowWithPanel(title: "Resampling", icon: "scale.3d", value: viewModel.outputResamplingDisplayString, panel: .outputResampling, bodyFont: bodyFont)
          }
          .padding(8)
          .background(menuRowBubble)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          
          gameMenuSectionHeader("Performance", fontSize: capFont)
          VStack(spacing: 0) {
            gameMenuRowWithPanel(title: "Speed", icon: "gauge.with.dots.needle.67percent", value: viewModel.speedDisplayString, panel: .speed, bodyFont: bodyFont)
            gameMenuDivider
            gameMenuInterpreterRow(bodyFont: bodyFont)
            gameMenuDivider
            gameMenuRowWithPanel(title: "Game", icon: "cpu", value: useSafeCoreForCurrentGame ? "Safe core: On" : "Safe core: Off", panel: .gameOptions, bodyFont: bodyFont)
          }
          .padding(8)
          .background(menuRowBubble)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          
          gameMenuSectionHeader("Save State", fontSize: capFont)
          VStack(spacing: 6) {
            gameMenuRowWithPanel(title: "Slot", icon: "number", value: "Slot \(viewModel.stateSlot)", panel: .slot, bodyFont: bodyFont)
            HStack(spacing: 6) {
              gameMenuPrimaryButton(title: "Load", icon: "arrow.down.doc.fill", action: viewModel.loadState, bodyFont: bodyFont)
              gameMenuPrimaryButton(title: "Save", icon: "arrow.up.doc.fill", action: viewModel.saveState, bodyFont: bodyFont)
            }
          }
          .padding(10)
          .background(menuRowBubble)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          
          gameMenuSectionHeader("Cheats", fontSize: capFont)
          gameMenuCheatsBlock(bodyFont: bodyFont)
          
          if viewModel.emulateSkylanderPortal && viewModel.isWiiGame {
            gameMenuSectionHeader("Tools", fontSize: capFont)
            Button(action: { viewModel.showingSkylanderAlert = true }) {
              HStack {
                Image(systemName: "externaldrive")
                Text("Skylanders Portal")
                  .font(.system(size: bodyFont))
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.caption2.weight(.semibold))
                  .foregroundColor(Color(UIColor.tertiaryLabel))
              }
              .padding(10)
              .background(menuRowBubble)
              .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .foregroundColor(Color(UIColor.label))
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    .frame(maxHeight: min(360, UIScreen.main.bounds.height * 0.5))
    .background(Color.clear)
    .onAppear { viewModel.refreshPostProcessingShaderList() }
  }
  
  private func gameMenuRowWithPanel(title: String, icon: String, value: String, panel: GameMenuPanel, bodyFont: CGFloat = 12) -> some View {
    let isOpen = openPanels.contains(panel)
    return Button(action: { togglePanel(panel) }) {
      HStack {
        Label(title, systemImage: icon)
          .font(.system(size: bodyFont))
          .foregroundStyle(.secondary)
        Spacer()
        Text(value)
          .font(.system(size: bodyFont - 1))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Image(systemName: "chevron.right")
          .font(.system(size: bodyFont - 2, weight: .semibold))
          .foregroundStyle(isOpen ? Color.accentColor : .secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(isOpen ? Color.accentColor.opacity(0.12) : Color.clear)
    }
    .buttonStyle(.plain)
  }
  
  @ViewBuilder
  private func gameMenuSidePanelContent(_ panel: GameMenuPanel, panelWidth: CGFloat) -> some View {
    let capFont = Self.menuFontSize(caption: true)
    ScrollView(.vertical, showsIndicators: false) {
      VStack(spacing: 4) {
        switch panel {
        case .controller:
          controllerPanelContent(capFont: capFont)
        case .gameOptions:
          gameOptionsPanelContent(capFont: capFont)
        case .resolution:
          ForEach(internalResolutionOptions, id: \.1) { option in
            gameMenuPanelOption(option.0, selected: viewModel.internalResolution == option.1, fontSize: capFont) {
              viewModel.setInternalResolution(option.1)
            }
          }
        case .msaa:
          ForEach(MSAAOptions.all, id: \.1) { option in
            gameMenuPanelOption(option.0, selected: viewModel.msaa == option.1, fontSize: capFont) {
              viewModel.setMsaa(option.1)
            }
          }
        case .postProcessing:
          Group {
            ForEach(viewModel.postProcessingShaderNames, id: \.self) { name in
              let isNone = (name == "None")
              let selected = isNone
                ? viewModel.selectedPostProcessingShaders.isEmpty
                : viewModel.selectedPostProcessingShaders.contains(name)
              gameMenuPanelOption(name, selected: selected, fontSize: capFont) {
                if isNone {
                  // Clear all selections
                  viewModel.selectedPostProcessingShaders.removeAll()
                  UserDefaults.standard.set([String](), forKey: "DOLSelectedPostProcessingShaders")
                  viewModel.setPostProcessingShader("")
                } else {
                  viewModel.togglePostProcessingShader(name)
                }
              }
            }
            gameMenuShaderImportCard(fontSize: capFont) {
              showShaderImporter = true
            }
          }
          .onAppear { viewModel.refreshPostProcessingShaderList() }
        case .outputResampling:
          ForEach(outputResamplingOptions, id: \.1) { option in
            gameMenuPanelOption(option.0, selected: viewModel.outputResampling == option.1, fontSize: capFont) {
              viewModel.setOutputResampling(option.1)
            }
          }
        case .speed:
          ForEach(speedOptions, id: \.1) { option in
            gameMenuPanelOption(option.0, selected: viewModel.emulationSpeed == option.1, fontSize: capFont) {
              viewModel.setEmulationSpeed(option.1)
            }
          }
        case .slot:
          ForEach(1...10, id: \.self) { slot in
            gameMenuPanelOption("Slot \(slot)", selected: viewModel.stateSlot == slot, fontSize: capFont) {
              viewModel.setStateSlot(slot)
            }
          }
        }
      }
      .padding(8)
      .padding(.bottom, 10)
    }
    .frame(maxHeight: min(320, UIScreen.main.bounds.height * 0.45))
  }
  
  private func gameOptionsPanelContent(capFont: CGFloat) -> some View {
    let gameId = DOLGeckoBridge.currentGameId() ?? ""
    return Group {
      if !gameId.isEmpty {
        Toggle(isOn: $useSafeCoreForCurrentGame) {
          Text("Use safe core for this game")
            .font(.system(size: capFont))
        }
        .tint(Color.accentColor)
        .onAppear { useSafeCoreForCurrentGame = SafeCoreGameIDsStorage.contains(gameId) }
        .onChange(of: useSafeCoreForCurrentGame) { _, on in
          if on { SafeCoreGameIDsStorage.add(gameId) } else { SafeCoreGameIDsStorage.remove(gameId) }
        }
      } else {
        Text("No game loaded")
          .font(.system(size: capFont))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func panelTitle(_ panel: GameMenuPanel) -> String {
    switch panel {
    case .controller: return "Controller"
    case .gameOptions: return "Game"
    case .resolution: return "Resolution"
    case .msaa: return "MSAA"
    case .postProcessing: return "Post-Processing"
    case .outputResampling: return "Resampling"
    case .speed: return "Speed"
    case .slot: return "Slot"
    }
  }
  
  private func controllerPanelContent(capFont: CGFloat) -> some View {
    VStack(spacing: 4) {
      Button {
        setPreferredInputTouch(true)
      } label: {
        HStack {
          Text("Touch")
            .font(.system(size: capFont + 1))
            .foregroundColor(Color(UIColor.label))
          Spacer()
          if preferredTouch {
            Image(systemName: "checkmark")
              .font(.system(size: capFont, weight: .semibold))
              .foregroundColor(Color.accentColor)
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(menuRowBubble)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      Button {
        setPreferredInputTouch(false)
      } label: {
        HStack {
          Text("Controller")
            .font(.system(size: capFont + 1))
            .foregroundColor(Color(UIColor.label))
          Spacer()
          if !preferredTouch {
            Image(systemName: "checkmark")
              .font(.system(size: capFont, weight: .semibold))
              .foregroundColor(Color.accentColor)
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(menuRowBubble)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
    }
  }
  
  private let outputResamplingOptions: [(String, Int)] = [
    ("Default", 0),
    ("Bilinear", 1),
    ("BSpline", 2),
    ("Mitchell-Netravali", 3),
    ("Catmull-Rom", 4),
    ("Sharp Bilinear", 5),
    ("Area", 6),
  ]
  
  private func gameMenuPanelOption(_ title: String, selected: Bool, fontSize: CGFloat = 11, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Text(title)
          .font(.system(size: fontSize))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Spacer()
        if selected {
          Image(systemName: "checkmark")
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(Color.accentColor)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 8)
      .background(selected ? Color.accentColor.opacity(0.2) : menuRowBubble)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  /// Empty card with plus to import a shader file into the Shaders directory.
  private func gameMenuShaderImportCard(fontSize: CGFloat = 11, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: fontSize + 2))
          .foregroundStyle(Color.accentColor)
        Text("Import shader")
          .font(.system(size: fontSize))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity)
      .background(menuRowBubble)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }
  
  /// Grey bubble behind value rows so game shows through between them.
  private var menuRowBubble: Color {
    Color(UIColor.tertiarySystemFill).opacity(0.92)
  }
  
  private func gameMenuSectionHeader(_ title: String, fontSize: CGFloat = 11) -> some View {
    Text(title.uppercased())
      .font(.system(size: fontSize, weight: .semibold))
      .foregroundStyle(.secondary)
      .padding(.bottom, 3)
  }
  
  private var gameMenuDivider: some View {
    Divider()
      .padding(.leading, 14)
  }
  
  // MARK: - Inline menu rows
  
  private func gameMenuAspectRow(bodyFont: CGFloat = 12) -> some View {
    let landscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
    return VStack(spacing: 6) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Aspect Ratio")
          .font(.system(size: max(8, bodyFont - 2)))
          .foregroundStyle(.secondary)
          .padding(.leading, 2)
        Picker("Aspect Ratio", selection: Binding(
          get: { viewModel.aspectRatio },
          set: { viewModel.setAspectRatio($0) }
        )) {
          Text("16:9").tag(1)
          if landscape {
            Text("4:3").tag(2)
          }
          if !landscape {
            Text("Fill").tag(3)
          }
          Text("Full").tag(4)
        }
        .pickerStyle(.segmented)
        .font(.system(size: bodyFont - 1))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
  
  private func gameMenuSSAARow(bodyFont: CGFloat = 12) -> some View {
    Toggle(isOn: Binding(
      get: { viewModel.ssaa },
      set: { viewModel.setSsaa($0) }
    )) {
      Label("SSAA", systemImage: "square.grid.3x3")
        .font(.system(size: bodyFont))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
  
  private func gameMenuMetalFXRow(bodyFont: CGFloat = 12) -> some View {
    Toggle(isOn: Binding(
      get: { viewModel.metalFXUpscaling },
      set: { viewModel.setMetalFXUpscaling($0) }
    )) {
      Label("MetalFX Upscaling", systemImage: "wand.and.stars")
        .font(.system(size: bodyFont))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
  
  private func gameMenuInterpreterRow(bodyFont: CGFloat = 12) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("CPU Core")
        .font(.system(size: max(8, bodyFont - 2)))
        .foregroundStyle(.secondary)
        .padding(.leading, 2)
      Picker("CPU Core", selection: Binding(
        get: { viewModel.cpuCore },
        set: { viewModel.setCpuCore($0) }
      )) {
        Text("Interp").tag(0)
        Text("Cached").tag(1)
        Text("Inline").tag(2)
      }
      .pickerStyle(.segmented)
      .font(.system(size: bodyFont - 1))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
  
  private func gameMenuWidescreenRow(bodyFont: CGFloat = 12) -> some View {
    Toggle(isOn: Binding(
      get: { viewModel.widescreen },
      set: { viewModel.setWidescreen($0) }
    )) {
      Label("Widescreen", systemImage: "rectangle.arrowtriangle.2.outward")
        .font(.system(size: bodyFont))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
  
  private func gameMenuHDRRow(bodyFont: CGFloat = 12) -> some View {
    Toggle(isOn: Binding(
      get: { viewModel.hdrOutput },
      set: { viewModel.setHdrOutput($0) }
    )) {
      Label("HDR Output", systemImage: "sun.max.fill")
        .font(.system(size: bodyFont))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
  
  private func gameMenuEditLayoutRow(bodyFont: CGFloat = 12) -> some View {
    Button {
      editingLayout.toggle()
      TCLayoutManager.shared.setEditMode(editingLayout)
    } label: {
      HStack {
        Image(systemName: editingLayout ? "checkmark.circle.fill" : "arrow.up.and.down.and.arrow.left.and.right")
          .foregroundStyle(editingLayout ? .green : .secondary)
        Text(editingLayout ? "Done Editing" : "Edit Layout")
          .font(.system(size: bodyFont))
          .foregroundStyle(editingLayout ? .green : .secondary)
        Spacer()
        if editingLayout {
          Text("Drag controls")
            .font(.system(size: bodyFont - 2))
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private func gameMenuPrimaryButton(title: String, icon: String, action: @escaping () -> Void, bodyFont: CGFloat = 12) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: bodyFont, weight: .semibold))
        Text(title)
          .font(.system(size: bodyFont, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(Color.accentColor)
      .foregroundColor(.white)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
  }
  
  @ViewBuilder
  private func gameMenuCheatsBlock(bodyFont: CGFloat = 12) -> some View {
    if viewModel.cheats.isEmpty {
      Button(action: { viewModel.downloadCheats() }) {
        HStack {
          Image(systemName: "arrow.down.circle")
          Text("Download Cheats")
            .font(.system(size: bodyFont))
          if viewModel.isDownloadingCheats {
            Spacer()
            ProgressView()
          }
        }
        .padding(10)
        .background(menuRowBubble)
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .disabled(viewModel.isDownloadingCheats)
      .foregroundColor(Color(UIColor.label))
      .buttonStyle(.plain)
    } else {
      VStack(spacing: 0) {
        ForEach(Array(viewModel.cheats.enumerated()), id: \.element.codeIndex) { index, cheat in
          if index > 0 {
            Divider().padding(.leading, 12)
          }
          Button(action: { viewModel.setCheatEnabled(!cheat.enabled, at: index) }) {
            HStack {
              Text(cheat.name)
                .font(.system(size: bodyFont))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(Color(UIColor.label))
              Spacer()
              Image(systemName: cheat.enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: bodyFont))
                .foregroundColor(cheat.enabled ? Color.accentColor : Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
          }
          .buttonStyle(.plain)
        }
      }
      .background(menuRowBubble)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }
  
  // MARK: - Helper Functions
  
  @ViewBuilder
  private var touchControllerOverlay: some View {
    if !preferredTouch {
      EmptyView()
    } else {
      switch viewModel.visibleTouchPad {
      case .none:
        EmptyView()
      case .gameCube:
        TouchControllerRepresentable(type: .gameCube, port: 0)
          .id("tc-gamecube-0-\(touchControlStyle.rawValue)")
      case .wiimote:
        TouchControllerRepresentable(type: .wiimote, port: 4)
          .id("tc-wiimote-4-\(touchControlStyle.rawValue)")
      case .sidewaysWiimote:
        TouchControllerRepresentable(type: .sidewaysWiimote, port: 4)
          .id("tc-sideways-4-\(touchControlStyle.rawValue)")
      case .classic:
        TouchControllerRepresentable(type: .classic, port: 4)
          .id("tc-classic-4-\(touchControlStyle.rawValue)")
      }
    }
  }
  
  private var internalResolutionOptions: [(String, Int)] {
    [
      ("1x (640x528)", 1),
      ("2x (1280x1056)", 2),
      ("3x (1920x1584)", 3),
      ("4x (2560x2112)", 4),
      ("5x (3200x2640)", 5),
      ("6x (3840x3168)", 6)
    ]
  }
  
  private var speedOptions: [(String, Float)] {
    [
      ("Unlimited", 0),
      ("0.5x", 0.5),
      ("1x (Normal)", 1.0),
      ("1.5x", 1.5),
      ("2x", 2.0),
      ("3x", 3.0)
    ]
  }
  
  // MARK: - Start Emulation
  
  private func startEmulationIfNeeded() {
    guard let bootParameter = bootParameter else { return }
    // Use the Swift-compatible method that accepts id/AnyObject
    EmulationCoordinator.shared().runEmulation(withBootParameterObject: bootParameter)
  }
}

struct RendererContainerView: UIViewRepresentable {
  func makeUIView(context: Context) -> RendererHostView {
    let view = RendererHostView()
    view.backgroundColor = .black
    EmulationCoordinator.shared().registerMainDisplay(view)
    return view
  }

  func updateUIView(_ uiView: RendererHostView, context: Context) {
    uiView.setNeedsLayout()
    uiView.layoutIfNeeded()
  }
  
  static func dismantleUIView(_ uiView: RendererHostView, coordinator: ()) {
    // Remove the Metal view from this host so it doesn't render into a dead view
    for subview in uiView.subviews {
      subview.removeFromSuperview()
    }
  }
}

/// Display size is always taken from this view’s bounds (set by SwiftUI from rendererLayout); MSAA/MetalFX only trigger a forced backend resize with the same size.
class RendererHostView: UIView {
  private var lastBounds: CGRect = .zero
  private var lastAspectRatio: Int = -1
  private var lastInternalResolution: Int = -1
  private var lastMsaa: Int = -1
  private var lastMetalFX: Bool = false

  override func layoutSubviews() {
    super.layoutSubviews()

    if UIApplication.shared.applicationState != .active {
      return
    }

    let aspectRatio = Int(DOLConfigBridge.aspectRatio())
    let internalResolution = Int(DOLConfigBridge.internalResolution())
    let msaa = Int(DOLConfigBridge.msaa())
    let metalFX = DOLConfigBridge.metalFXUpscaling()
    let boundsChanged = bounds.width != lastBounds.width || bounds.height != lastBounds.height
    let configChanged = aspectRatio != lastAspectRatio || internalResolution != lastInternalResolution
      || msaa != lastMsaa || metalFX != lastMetalFX
    guard bounds.width > 0, bounds.height > 0 else { return }
    if boundsChanged || configChanged {
      lastBounds = bounds
      lastAspectRatio = aspectRatio
      lastInternalResolution = internalResolution
      lastMsaa = msaa
      lastMetalFX = metalFX
      if configChanged && !boundsChanged {
        EmulationCoordinator.shared().notifySurfaceResizeForced()
      } else {
        EmulationCoordinator.shared().notifySurfaceResize()
        if boundsChanged {
          DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            EmulationCoordinator.shared().notifySurfaceResize()
          }
        }
      }
    }
  }
}

enum TouchControllerType {
  case gameCube
  case wiimote
  case sidewaysWiimote
  case classic
  
  var nibName: String {
    switch self {
    case .gameCube: return "TCGameCubePad"
    case .wiimote: return "TCWiiPad"
    case .sidewaysWiimote: return "TCSidewaysWiiPad"
    case .classic: return "TCClassicWiiPad"
    }
  }
}

struct TouchControllerRepresentable: UIViewRepresentable {
  let type: TouchControllerType
  let port: Int
  
  func makeUIView(context: Context) -> TouchControllerContainerView {
    let container = TouchControllerContainerView()
    container.installTouchController(type: type, port: port)
    return container
  }
  
  func updateUIView(_ uiView: TouchControllerContainerView, context: Context) {
    if uiView.currentType != type || uiView.currentPort != port {
      uiView.installTouchController(type: type, port: port)
    }
  }
}

class TouchControllerContainerView: UIView {
  private var loadedController: TCView?
  private(set) var currentType: TouchControllerType?
  private(set) var currentPort: Int = 0
  
  func installTouchController(type: TouchControllerType, port: Int) {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in
        self?.installTouchController(type: type, port: port)
      }
      return
    }
    guard currentType != type || currentPort != port else { return }
    currentType = type
    currentPort = port
    
    loadedController?.removeFromSuperview()
    loadedController = nil
    
    backgroundColor = .clear

    let tcView: TCView
    switch type {
    case .gameCube:
      tcView = TCGameCubePad(frame: .zero)
    case .wiimote:
      tcView = TCWiiPad(frame: .zero)
    case .sidewaysWiimote:
      tcView = TCSidewaysWiiPad(frame: .zero)
    case .classic:
      tcView = TCClassicWiiPad(frame: .zero)
    }
    
    tcView.translatesAutoresizingMaskIntoConstraints = false
    tcView.backgroundColor = UIColor.clear
    tcView.port = port
    addSubview(tcView)
    
    NSLayoutConstraint.activate([
      tcView.topAnchor.constraint(equalTo: topAnchor),
      tcView.bottomAnchor.constraint(equalTo: bottomAnchor),
      tcView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tcView.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])
    
    loadedController = tcView
  }
}

struct EmulationNavigationView: View {
  let bootParameter: AnyObject?
  
  var body: some View {
    EmulationView(bootParameter: bootParameter)
      .ignoresSafeArea()
  }
}

@objc(EmulationSwiftUIHostingController)
class EmulationSwiftUIHostingController: UIViewController {
  private var _bootParameter: AnyObject?
  
  @objc var bootParameter: AnyObject? {
    get { _bootParameter }
    set {
      _bootParameter = newValue
      updateHostingController()
    }
  }
  
  private var hostingController: UIHostingController<EmulationNavigationView>?
  
  @objc
  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }
  
  @objc
  convenience init() {
    self.init(nibName: nil, bundle: nil)
  }
  
  @objc
  convenience init(bootParameter: AnyObject?) {
    self.init(nibName: nil, bundle: nil)
    self._bootParameter = bootParameter
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    modalPresentationStyle = .fullScreen
    edgesForExtendedLayout = .all
    extendedLayoutIncludesOpaqueBars = true
    view.backgroundColor = .black
    setupHostingController()
    NotificationCenter.default.addObserver(self, selector: #selector(handleDismissEmulation), name: NSNotification.Name("DOLDismissEmulationView"), object: nil)
  }
  
  @objc private func handleDismissEmulation() {
    dismiss(animated: true)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // Remove observer and release hosting controller to break retain cycles
    NotificationCenter.default.removeObserver(self)
    hostingController?.willMove(toParent: nil)
    hostingController?.view.removeFromSuperview()
    hostingController?.removeFromParent()
    hostingController = nil
  }
  
  private var isNegatingInsets = false
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard !isNegatingInsets else { return }
    isNegatingInsets = true
    // Natural insets = reported insets minus our additional adjustments
    let reported = view.safeAreaInsets
    let additional = additionalSafeAreaInsets
    let natural = UIEdgeInsets(
      top: reported.top - additional.top,
      left: reported.left - additional.left,
      bottom: reported.bottom - additional.bottom,
      right: reported.right - additional.right
    )
    // Negate natural insets so total safe area becomes zero
    let negated = UIEdgeInsets(
      top: -natural.top,
      left: -natural.left,
      bottom: -natural.bottom,
      right: -natural.right
    )
    if additional != negated {
      additionalSafeAreaInsets = negated
    }
    isNegatingInsets = false
  }
  
  private func setupHostingController() {
    let rootView = EmulationNavigationView(bootParameter: _bootParameter)
    let hosting = UIHostingController(rootView: rootView)
    if #available(iOS 16.4, *) {
      hosting.safeAreaRegions = []
    }
    hostingController = hosting
    
    addChild(hosting)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hosting.view)
    
    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
    
    hosting.didMove(toParent: self)
  }
  
  private func updateHostingController() {
    hostingController?.rootView = EmulationNavigationView(bootParameter: _bootParameter)
  }
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }
  
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return .all
  }
  
  override var childForStatusBarHidden: UIViewController? {
    return hostingController
  }
  
  override var childForHomeIndicatorAutoHidden: UIViewController? {
    return hostingController
  }
  
  override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
    return hostingController
  }
}

#if DEBUG
struct EmulationView_Previews: PreviewProvider {
  static var previews: some View {
    EmulationNavigationView(bootParameter: nil)
  }
}
#endif

