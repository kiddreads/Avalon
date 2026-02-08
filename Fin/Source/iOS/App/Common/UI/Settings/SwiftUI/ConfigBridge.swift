// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import SwiftUI

/// SwiftUI-compatible wrapper around Dolphin's configuration system.
/// Uses DOLConfigBridge (Obj-C++) under the hood.
@MainActor
final class ConfigBridge: ObservableObject {
  static let shared = ConfigBridge()
  
  // MARK: - Performance Settings
  
  @Published var dualCore: Bool {
    didSet { DOLConfigBridge.setDualCore(dualCore) }
  }
  
  @Published var idleSkip: Bool {
    didSet { DOLConfigBridge.setIdleSkip(idleSkip) }
  }
  
  @Published var emulationSpeed: Float {
    didSet { DOLConfigBridge.setEmulationSpeed(emulationSpeed) }
  }
  
  @Published var interpreterCacheSize: Int {
    didSet { DOLConfigBridge.setInterpreterCacheSize(Int32(interpreterCacheSize)) }
  }
  
  /// CPU core: 0 = Interpreter, 1 = Cached Interpreter, 2 = Inline Cached Interpreter
  @Published var cpuCore: Int {
    didSet { DOLConfigBridge.setCpuCore(Int32(cpuCore)) }
  }

  // MARK: - Graphics Settings
  
  @Published var useGPUVertexDecode: Bool {
    didSet { DOLConfigBridge.setUseGPUVertexDecode(useGPUVertexDecode) }
  }
  
  @Published var useNativeVideoDecode: Bool {
    didSet { DOLConfigBridge.setUseNativeVideoDecode(useNativeVideoDecode) }
  }
  
  @Published var metalFXUpscaling: Bool {
    didSet {
      DOLConfigBridge.setMetalFXUpscaling(metalFXUpscaling)
      // MetalFX should output HDR when enabled
      if metalFXUpscaling && !hdrOutput {
        hdrOutput = true
      }
      EmulationCoordinator.shared().notifySurfaceResize()
    }
  }
  
  @Published var metalFXOutputWidth: Int {
    didSet {
      DOLConfigBridge.setMetalFXOutputWidth(Int32(metalFXOutputWidth))
      EmulationCoordinator.shared().notifySurfaceResize()
    }
  }
  
  @Published var metalFXOutputHeight: Int {
    didSet {
      DOLConfigBridge.setMetalFXOutputHeight(Int32(metalFXOutputHeight))
      EmulationCoordinator.shared().notifySurfaceResize()
    }
  }
  
  @Published var metalFXOutput125xInternal: Bool {
    didSet {
      DOLConfigBridge.setMetalFXOutput125xInternal(metalFXOutput125xInternal)
      EmulationCoordinator.shared().notifySurfaceResize()
    }
  }
  
  @Published var internalResolution: Int {
    didSet {
      let safeValue = internalResolution == 0 ? 1 : internalResolution
      if internalResolution != safeValue {
        internalResolution = safeValue
        return
      }
      DOLConfigBridge.setInternalResolutionLive(Int32(internalResolution))
      DOLConfigBridge.setInternalResolution(Int32(internalResolution))
      EmulationCoordinator.shared().notifySurfaceResize()
    }
  }
  
  @Published var widescreen: Bool {
    didSet { DOLConfigBridge.setWidescreen(widescreen) }
  }
  
  @Published var vsync: Bool {
    didSet { DOLConfigBridge.setVsync(vsync) }
  }
  
  @Published var graphicsMods: Bool {
    didSet { DOLConfigBridge.setGraphicsMods(graphicsMods) }
  }
  
  @Published var showFPS: Bool {
    didSet { DOLConfigBridge.setShowFPS(showFPS) }
  }
  
  @Published var showSpeed: Bool {
    didSet { DOLConfigBridge.setShowSpeed(showSpeed) }
  }
  
  @Published var backendMultithreading: Bool {
    didSet { DOLConfigBridge.setBackendMultithreading(backendMultithreading) }
  }
  
  @Published var loadCustomTextures: Bool {
    didSet { DOLConfigBridge.setLoadCustomTextures(loadCustomTextures) }
  }
  
  @Published var msaa: Int {
    didSet {
      // Ensure MSAA is off when set to Off: never pass 0 to the core (1 = no multisampling).
      let effective = max(1, msaa)
      if effective != msaa { msaa = effective; return }
      DOLConfigBridge.setMsaaLive(Int32(effective))
      DOLConfigBridge.setMsaa(Int32(effective))
    }
  }
  
  @Published var aspectRatio: Int {
    didSet {
      DOLConfigBridge.setAspectRatioLive(Int32(aspectRatio))
      DOLConfigBridge.setAspectRatio(Int32(aspectRatio))
      EmulationCoordinator.shared().notifySurfaceResize()
    }
  }
  
  /// Shader Compilation Mode: 0=Sync, 1=Sync+Uber, 2=Async+Uber, 3=Async+Skip
  @Published var shaderCompilationMode: Int {
    didSet { DOLConfigBridge.setShaderCompilationMode(Int32(shaderCompilationMode)) }
  }
  
  // MARK: - Graphics Hacks
  
  @Published var immediateXFB: Bool {
    didSet { DOLConfigBridge.setImmediateXFB(immediateXFB) }
  }
  
  @Published var skipEFBAccess: Bool {
    didSet { DOLConfigBridge.setSkipEFBAccess(skipEFBAccess) }
  }
  
  @Published var deferEFBInvalidation: Bool {
    didSet { DOLConfigBridge.setDeferEFBInvalidation(deferEFBInvalidation) }
  }
  
  @Published var deferEFBCopies: Bool {
    didSet { DOLConfigBridge.setDeferEFBCopies(deferEFBCopies) }
  }
  
  @Published var efbEmulateFormatChanges: Bool {
    didSet { DOLConfigBridge.setEfbEmulateFormatChanges(efbEmulateFormatChanges) }
  }
  
  @Published var skipEFBCopyToRAM: Bool {
    didSet { DOLConfigBridge.setSkipEFBCopyToRAM(skipEFBCopyToRAM) }
  }
  
  @Published var skipXFBCopyToRAM: Bool {
    didSet { DOLConfigBridge.setSkipXFBCopyToRAM(skipXFBCopyToRAM) }
  }
  
  @Published var skipDuplicateXFBs: Bool {
    didSet { DOLConfigBridge.setSkipDuplicateXFBs(skipDuplicateXFBs) }
  }
  
  @Published var fastDepthCalc: Bool {
    didSet { DOLConfigBridge.setFastDepthCalc(fastDepthCalc) }
  }
  
  @Published var vertexRounding: Bool {
    didSet { DOLConfigBridge.setVertexRounding(vertexRounding) }
  }
  
  @Published var boundingBoxEnable: Bool {
    didSet { DOLConfigBridge.setBoundingBoxEnable(boundingBoxEnable) }
  }
  
  @Published var saveTextureCacheToState: Bool {
    didSet { DOLConfigBridge.setSaveTextureCacheToState(saveTextureCacheToState) }
  }
  
  @Published var viSkip: Bool {
    didSet { DOLConfigBridge.setViSkip(viSkip) }
  }
  
  @Published var gpuTextureDecoding: Bool {
    didSet { DOLConfigBridge.setGpuTextureDecoding(gpuTextureDecoding) }
  }
  
  @Published var textureCacheAccuracy: Int {
    didSet { DOLConfigBridge.setTextureCacheAccuracy(Int32(textureCacheAccuracy)) }
  }
  
  @Published var forceProgressiveScan: Bool {
    didSet { DOLConfigBridge.setForceProgressiveScan(forceProgressiveScan) }
  }
  
  @Published var disableCopyToVRAM: Bool {
    didSet { DOLConfigBridge.setDisableCopyToVRAM(disableCopyToVRAM) }
  }
  
  @Published var copyEFBScaled: Bool {
    didSet { DOLConfigBridge.setCopyEFBScaled(copyEFBScaled) }
  }
  
  @Published var fastTextureSampling: Bool {
    didSet { DOLConfigBridge.setFastTextureSampling(fastTextureSampling) }
  }
  
  @Published var noMipmapping: Bool {
    didSet { DOLConfigBridge.setNoMipmapping(noMipmapping) }
  }
  
  // MARK: - Graphics Enhancements
  
  @Published var textureFiltering: Int {
    didSet { DOLConfigBridge.setTextureFiltering(Int32(textureFiltering)) }
  }
  
  @Published var anisotropicFiltering: Int {
    didSet { DOLConfigBridge.setAnisotropicFiltering(Int32(anisotropicFiltering)) }
  }
  
  @Published var ssaa: Bool {
    didSet { DOLConfigBridge.setSsaa(ssaa) }
  }
  
  @Published var pixelLighting: Bool {
    didSet { DOLConfigBridge.setPixelLighting(pixelLighting) }
  }
  
  @Published var forceTrueColor: Bool {
    didSet { DOLConfigBridge.setForceTrueColor(forceTrueColor) }
  }
  
  @Published var disableCopyFilter: Bool {
    didSet { DOLConfigBridge.setDisableCopyFilter(disableCopyFilter) }
  }
  
  @Published var arbitraryMipmapDetection: Bool {
    didSet { DOLConfigBridge.setArbitraryMipmapDetection(arbitraryMipmapDetection) }
  }
  
  @Published var disableFog: Bool {
    didSet { DOLConfigBridge.setDisableFog(disableFog) }
  }
  
  /// Output resampling: 0=Default, 1=Bilinear, 2=BSpline, 3=MitchellNetravali, 4=CatmullRom, 5=SharpBilinear, 6=AreaSampling
  @Published var outputResampling: Int {
    didSet { DOLConfigBridge.setOutputResampling(Int32(outputResampling)) }
  }
  
  @Published var hdrOutput: Bool {
    didSet {
      DOLConfigBridge.setHdrOutput(hdrOutput)
      EmulationCoordinator.shared().notifySurfaceResizeForced()
    }
  }
  
  /// Exposure for HDR/tone mapping (1.0 = no adjustment). Post-processing shaders can use this.
  @Published var exposure: Float {
    didSet { DOLConfigBridge.setExposure(exposure) }
  }
  
  @Published var cacheHiresTextures: Bool {
    didSet { DOLConfigBridge.setCacheHiresTextures(cacheHiresTextures) }
  }
  
  @Published var arbitraryMipmapDetectionThreshold: Float {
    didSet { DOLConfigBridge.setArbitraryMipmapDetectionThreshold(arbitraryMipmapDetectionThreshold) }
  }
  
  /// Post-processing shader name (e.g. "Anime4K_Upscale_CNN_x2_M"). Empty = none.
  @Published var postProcessingShader: String {
    didSet {
      DOLConfigBridge.setPostProcessingShader(postProcessingShader)
      EmulationCoordinator.shared().notifySurfaceResizeForced()
    }
  }
  
  // MARK: - Core Settings
  
  @Published var dspHLE: Bool {
    didSet { DOLConfigBridge.setDspHLE(dspHLE) }
  }
  
  @Published var syncGPU: Bool {
    didSet { DOLConfigBridge.setSyncGPU(syncGPU) }
  }
  
  @Published var fastDiscSpeed: Bool {
    didSet { DOLConfigBridge.setFastDiscSpeed(fastDiscSpeed) }
  }
  
  @Published var overclockEnable: Bool {
    didSet { DOLConfigBridge.setOverclockEnable(overclockEnable) }
  }
  
  @Published var overclock: Float {
    didSet { DOLConfigBridge.setOverclock(overclock) }
  }
  
  @Published var mmu: Bool {
    didSet { DOLConfigBridge.setMmu(mmu) }
  }
  
  @Published var audioLatency: Int {
    didSet { DOLConfigBridge.setAudioLatency(Int32(audioLatency)) }
  }
  
  @Published var skipIPL: Bool {
    didSet { DOLConfigBridge.setSkipIPL(skipIPL) }
  }
  
  @Published var gcLanguage: Int {
    didSet { DOLConfigBridge.setGcLanguage(Int32(gcLanguage)) }
  }
  
  // MARK: - Audio Settings
  
  @Published var audioVolume: Int {
    didSet { DOLConfigBridge.setAudioVolume(Int32(audioVolume)) }
  }
  
  @Published var dpl2Decoder: Bool {
    didSet { DOLConfigBridge.setDpl2Decoder(dpl2Decoder) }
  }
  
  @Published var preferSpatialAudio: Bool {
    didSet { DOLConfigBridge.setPreferSpatialAudio(preferSpatialAudio) }
  }
  
  /// 0 = Mono, 1 = Stereo, 2 = Surround (6ch)
  @Published var audioOutputMode: Int {
    didSet { DOLConfigBridge.setAudioOutputMode(Int32(audioOutputMode)) }
  }
  
  @Published var audioUpsampling: Bool {
    didSet { DOLConfigBridge.setAudioUpsampling(audioUpsampling) }
  }
  
  @Published var audioStretch: Bool {
    didSet { DOLConfigBridge.setAudioStretch(audioStretch) }
  }
  
  @Published var audioBufferSize: Int {
    didSet { DOLConfigBridge.setAudioBufferSize(Int32(audioBufferSize)) }
  }
  
  @Published var audioBackend: String {
    didSet {
      DOLConfigBridge.setAudioBackend(audioBackend)
      // When Bell backend is selected, auto-enable Bell features
      // When switching away from Bell, disable Bell features
      if audioBackend == "Bell" {
        bellAudioEnabled = true
        bellAudioAdaptiveBuffering = true
        bellAudioNEONMixing = true
        bellAudioDrivenPacing = true
        bellAudioUnderrunProtection = true
        bellAudioDynamicRateCorrection = true
        bellAudioHQProcessing = true
      } else if oldValue == "Bell" {
        // Switching away from Bell - disable features
        bellAudioEnabled = false
        bellAudioAdaptiveBuffering = false
        bellAudioNEONMixing = false
        bellAudioDrivenPacing = false
        bellAudioUnderrunProtection = false
        bellAudioDynamicRateCorrection = false
        bellAudioHQProcessing = false
      }
    }
  }
  
  // MARK: - Interface Settings
  
  @Published var useGameCovers: Bool {
    didSet { DOLConfigBridge.setUseGameCovers(useGameCovers) }
  }
  
  @Published var confirmOnStop: Bool {
    didSet { DOLConfigBridge.setConfirmOnStop(confirmOnStop) }
  }
  
  @Published var panicHandlers: Bool {
    didSet { DOLConfigBridge.setPanicHandlers(panicHandlers) }
  }
  
  @Published var osdMessages: Bool {
    didSet { DOLConfigBridge.setOsdMessages(osdMessages) }
  }
  
  @Published var skipNKitWarning: Bool {
    didSet { DOLConfigBridge.setSkipNKitWarning(skipNKitWarning) }
  }
  
  @Published var pauseWhenInMenu: Bool {
    didSet { DOLConfigBridge.setPauseWhenInMenu(pauseWhenInMenu) }
  }
  
  @Published var abortOnPanicAlert: Bool {
    didSet { DOLConfigBridge.setAbortOnPanicAlert(abortOnPanicAlert) }
  }
  
  @Published var cheatsEnabled: Bool {
    didSet { DOLConfigBridge.setCheatsEnabled(cheatsEnabled) }
  }
  
  // MARK: - Experimental Settings
  
  @Published var fastmem: Bool {
    didSet { DOLConfigBridge.setFastmem(fastmem) }
  }
  
  @Published var mismatchedRegionSettings: Bool {
    didSet { DOLConfigBridge.setMismatchedRegionSettings(mismatchedRegionSettings) }
  }
  
  @Published var autoDiscChange: Bool {
    didSet { DOLConfigBridge.setAutoDiscChange(autoDiscChange) }
  }
  
  // MARK: - Bell Audio (Experimental iOS Audio Improvements)
  
  @Published var bellAudioEnabled: Bool {
    didSet { DOLConfigBridge.setBellAudioEnabled(bellAudioEnabled) }
  }
  
  @Published var bellAudioAdaptiveBuffering: Bool {
    didSet { DOLConfigBridge.setBellAudioAdaptiveBuffering(bellAudioAdaptiveBuffering) }
  }
  
  @Published var bellAudioNEONMixing: Bool {
    didSet { DOLConfigBridge.setBellAudioNEONMixing(bellAudioNEONMixing) }
  }
  
  @Published var bellAudioDrivenPacing: Bool {
    didSet { DOLConfigBridge.setBellAudioDrivenPacing(bellAudioDrivenPacing) }
  }
  
  @Published var bellAudioUnderrunProtection: Bool {
    didSet { DOLConfigBridge.setBellAudioUnderrunProtection(bellAudioUnderrunProtection) }
  }
  
  @Published var bellAudioDynamicRateCorrection: Bool {
    didSet { DOLConfigBridge.setBellAudioDynamicRateCorrection(bellAudioDynamicRateCorrection) }
  }
  
  @Published var bellAudioHQProcessing: Bool {
    didSet { DOLConfigBridge.setBellAudioHQProcessing(bellAudioHQProcessing) }
  }
  
  // MARK: - Wii Settings
  
  @Published var wiiProgressiveScan: Bool {
    didSet { DOLConfigBridge.setWiiProgressiveScan(wiiProgressiveScan) }
  }
  
  // MARK: - Controller Settings
  
  @Published var touchPadOpacity: Float {
    didSet { DOLConfigBridge.setTouchPadOpacity(touchPadOpacity) }
  }
  
  @Published var touchPadIRMode: Int {
    didSet { DOLConfigBridge.setTouchPadIRMode(Int32(touchPadIRMode)) }
  }
  
  @Published var muteSwitchMode: Int {
    didSet { DOLConfigBridge.setMuteSwitchMode(Int32(muteSwitchMode)) }
  }
  
  @Published var enableSavestates: Bool {
    didSet { DOLConfigBridge.setEnableSavestates(enableSavestates) }
  }
  
  @Published var rewindEnabled: Bool {
    didSet { DOLConfigBridge.setRewindEnabled(rewindEnabled) }
  }
  
  @Published var audioMuted: Bool {
    didSet { DOLConfigBridge.setAudioMuted(audioMuted) }
  }
  
  @Published var pauseOnPanic: Bool {
    didSet { DOLConfigBridge.setPauseOnPanic(pauseOnPanic) }
  }
  
  @Published var precisionFrameTiming: Bool {
    didSet { DOLConfigBridge.setPrecisionFrameTiming(precisionFrameTiming) }
  }
  
  @Published var viOverclockEnable: Bool {
    didSet { DOLConfigBridge.setViOverclockEnable(viOverclockEnable) }
  }
  
  @Published var viOverclock: Float {
    didSet { DOLConfigBridge.setViOverclock(viOverclock) }
  }
  
  @Published var earlyXFBOutput: Bool {
    didSet { DOLConfigBridge.setEarlyXFBOutput(earlyXFBOutput) }
  }
  
  // MARK: - Initialization
  
  private init() {
    // Load all values from config
    dualCore = DOLConfigBridge.dualCore()
    idleSkip = DOLConfigBridge.idleSkip()
    emulationSpeed = DOLConfigBridge.emulationSpeed()
    interpreterCacheSize = Int(DOLConfigBridge.interpreterCacheSize())
    cpuCore = Int(DOLConfigBridge.cpuCore())
    
    useGPUVertexDecode = DOLConfigBridge.useGPUVertexDecode()
    useNativeVideoDecode = DOLConfigBridge.useNativeVideoDecode()
    metalFXUpscaling = DOLConfigBridge.metalFXUpscaling()
    metalFXOutputWidth = Int(DOLConfigBridge.metalFXOutputWidth())
    metalFXOutputHeight = Int(DOLConfigBridge.metalFXOutputHeight())
    metalFXOutput125xInternal = DOLConfigBridge.metalFXOutput125xInternal()
    let initInternalResolution = Int(DOLConfigBridge.internalResolution())
    internalResolution = initInternalResolution == 0 ? 1 : initInternalResolution
    widescreen = DOLConfigBridge.widescreen()
    vsync = DOLConfigBridge.vsync()
    graphicsMods = DOLConfigBridge.graphicsMods()
    showFPS = DOLConfigBridge.showFPS()
    showSpeed = DOLConfigBridge.showSpeed()
    backendMultithreading = DOLConfigBridge.backendMultithreading()
    loadCustomTextures = DOLConfigBridge.loadCustomTextures()
    msaa = max(1, Int(DOLConfigBridge.msaa()))
    aspectRatio = Int(DOLConfigBridge.aspectRatio())
    shaderCompilationMode = Int(DOLConfigBridge.shaderCompilationMode())
    
    immediateXFB = DOLConfigBridge.immediateXFB()
    skipEFBAccess = DOLConfigBridge.skipEFBAccess()
    deferEFBInvalidation = DOLConfigBridge.deferEFBInvalidation()
    deferEFBCopies = DOLConfigBridge.deferEFBCopies()
    efbEmulateFormatChanges = DOLConfigBridge.efbEmulateFormatChanges()
    skipEFBCopyToRAM = DOLConfigBridge.skipEFBCopyToRAM()
    skipXFBCopyToRAM = DOLConfigBridge.skipXFBCopyToRAM()
    skipDuplicateXFBs = DOLConfigBridge.skipDuplicateXFBs()
    earlyXFBOutput = DOLConfigBridge.earlyXFBOutput()
    fastDepthCalc = DOLConfigBridge.fastDepthCalc()
    vertexRounding = DOLConfigBridge.vertexRounding()
    boundingBoxEnable = DOLConfigBridge.boundingBoxEnable()
    saveTextureCacheToState = DOLConfigBridge.saveTextureCacheToState()
    viSkip = DOLConfigBridge.viSkip()
    gpuTextureDecoding = DOLConfigBridge.gpuTextureDecoding()
    textureCacheAccuracy = Int(DOLConfigBridge.textureCacheAccuracy())
    forceProgressiveScan = DOLConfigBridge.forceProgressiveScan()
    disableCopyToVRAM = DOLConfigBridge.disableCopyToVRAM()
    copyEFBScaled = DOLConfigBridge.copyEFBScaled()
    fastTextureSampling = DOLConfigBridge.fastTextureSampling()
    noMipmapping = DOLConfigBridge.noMipmapping()
    
    textureFiltering = Int(DOLConfigBridge.textureFiltering())
    anisotropicFiltering = Int(DOLConfigBridge.anisotropicFiltering())
    ssaa = DOLConfigBridge.ssaa()
    pixelLighting = DOLConfigBridge.pixelLighting()
    forceTrueColor = DOLConfigBridge.forceTrueColor()
    disableCopyFilter = DOLConfigBridge.disableCopyFilter()
    arbitraryMipmapDetection = DOLConfigBridge.arbitraryMipmapDetection()
    disableFog = DOLConfigBridge.disableFog()
    outputResampling = Int(DOLConfigBridge.outputResampling())
    hdrOutput = DOLConfigBridge.hdrOutput()
    exposure = DOLConfigBridge.exposure()
    cacheHiresTextures = DOLConfigBridge.cacheHiresTextures()
    arbitraryMipmapDetectionThreshold = DOLConfigBridge.arbitraryMipmapDetectionThreshold()
    postProcessingShader = DOLConfigBridge.postProcessingShader() ?? ""
    
    pauseOnPanic = DOLConfigBridge.pauseOnPanic()
    precisionFrameTiming = DOLConfigBridge.precisionFrameTiming()
    viOverclockEnable = DOLConfigBridge.viOverclockEnable()
    viOverclock = DOLConfigBridge.viOverclock()
    dspHLE = DOLConfigBridge.dspHLE()
    syncGPU = DOLConfigBridge.syncGPU()
    fastDiscSpeed = DOLConfigBridge.fastDiscSpeed()
    overclockEnable = DOLConfigBridge.overclockEnable()
    overclock = DOLConfigBridge.overclock()
    mmu = DOLConfigBridge.mmu()
    audioLatency = Int(DOLConfigBridge.audioLatency())
    skipIPL = DOLConfigBridge.skipIPL()
    gcLanguage = Int(DOLConfigBridge.gcLanguage())
    
    audioVolume = Int(DOLConfigBridge.audioVolume())
    dpl2Decoder = DOLConfigBridge.dpl2Decoder()
    preferSpatialAudio = DOLConfigBridge.preferSpatialAudio()
    audioOutputMode = min(Int(DOLConfigBridge.audioOutputMode()), 2)
    audioUpsampling = DOLConfigBridge.audioUpsampling()
    audioStretch = DOLConfigBridge.audioStretch()
    audioBufferSize = Int(DOLConfigBridge.audioBufferSize())
    audioBackend = DOLConfigBridge.audioBackend()
    audioMuted = DOLConfigBridge.audioMuted()
    
    useGameCovers = DOLConfigBridge.useGameCovers()
    confirmOnStop = DOLConfigBridge.confirmOnStop()
    panicHandlers = DOLConfigBridge.panicHandlers()
    osdMessages = DOLConfigBridge.osdMessages()
    skipNKitWarning = DOLConfigBridge.skipNKitWarning()
    pauseWhenInMenu = DOLConfigBridge.pauseWhenInMenu()
    abortOnPanicAlert = DOLConfigBridge.abortOnPanicAlert()
    cheatsEnabled = DOLConfigBridge.cheatsEnabled()
    
    enableSavestates = DOLConfigBridge.enableSavestates()
    rewindEnabled = DOLConfigBridge.rewindEnabled()
    
    fastmem = DOLConfigBridge.fastmem()
    mismatchedRegionSettings = DOLConfigBridge.mismatchedRegionSettings()
    autoDiscChange = DOLConfigBridge.autoDiscChange()
    
    bellAudioEnabled = DOLConfigBridge.bellAudioEnabled()
    bellAudioAdaptiveBuffering = DOLConfigBridge.bellAudioAdaptiveBuffering()
    bellAudioNEONMixing = DOLConfigBridge.bellAudioNEONMixing()
    bellAudioDrivenPacing = DOLConfigBridge.bellAudioDrivenPacing()
    bellAudioUnderrunProtection = DOLConfigBridge.bellAudioUnderrunProtection()
    bellAudioDynamicRateCorrection = DOLConfigBridge.bellAudioDynamicRateCorrection()
    bellAudioHQProcessing = DOLConfigBridge.bellAudioHQProcessing()
    
    wiiProgressiveScan = DOLConfigBridge.wiiProgressiveScan()
    
    touchPadOpacity = DOLConfigBridge.touchPadOpacity()
    touchPadIRMode = Int(DOLConfigBridge.touchPadIRMode())
    muteSwitchMode = Int(DOLConfigBridge.muteSwitchMode())
  }
  
  /// Reload all values from the config system.
  /// Call this when returning to settings after gameplay.
  func reload() {
    dualCore = DOLConfigBridge.dualCore()
    idleSkip = DOLConfigBridge.idleSkip()
    emulationSpeed = DOLConfigBridge.emulationSpeed()
    interpreterCacheSize = Int(DOLConfigBridge.interpreterCacheSize())
    cpuCore = Int(DOLConfigBridge.cpuCore())
    
    useGPUVertexDecode = DOLConfigBridge.useGPUVertexDecode()
    useNativeVideoDecode = DOLConfigBridge.useNativeVideoDecode()
    metalFXUpscaling = DOLConfigBridge.metalFXUpscaling()
    metalFXOutputWidth = Int(DOLConfigBridge.metalFXOutputWidth())
    metalFXOutputHeight = Int(DOLConfigBridge.metalFXOutputHeight())
    metalFXOutput125xInternal = DOLConfigBridge.metalFXOutput125xInternal()
    let reloadInternalResolution = Int(DOLConfigBridge.internalResolution())
    internalResolution = reloadInternalResolution == 0 ? 1 : reloadInternalResolution
    widescreen = DOLConfigBridge.widescreen()
    vsync = DOLConfigBridge.vsync()
    graphicsMods = DOLConfigBridge.graphicsMods()
    showFPS = DOLConfigBridge.showFPS()
    showSpeed = DOLConfigBridge.showSpeed()
    backendMultithreading = DOLConfigBridge.backendMultithreading()
    loadCustomTextures = DOLConfigBridge.loadCustomTextures()
    msaa = max(1, Int(DOLConfigBridge.msaa()))
    aspectRatio = Int(DOLConfigBridge.aspectRatio())
    shaderCompilationMode = Int(DOLConfigBridge.shaderCompilationMode())
    
    immediateXFB = DOLConfigBridge.immediateXFB()
    skipEFBAccess = DOLConfigBridge.skipEFBAccess()
    deferEFBInvalidation = DOLConfigBridge.deferEFBInvalidation()
    deferEFBCopies = DOLConfigBridge.deferEFBCopies()
    efbEmulateFormatChanges = DOLConfigBridge.efbEmulateFormatChanges()
    skipEFBCopyToRAM = DOLConfigBridge.skipEFBCopyToRAM()
    skipXFBCopyToRAM = DOLConfigBridge.skipXFBCopyToRAM()
    skipDuplicateXFBs = DOLConfigBridge.skipDuplicateXFBs()
    earlyXFBOutput = DOLConfigBridge.earlyXFBOutput()
    fastDepthCalc = DOLConfigBridge.fastDepthCalc()
    vertexRounding = DOLConfigBridge.vertexRounding()
    boundingBoxEnable = DOLConfigBridge.boundingBoxEnable()
    saveTextureCacheToState = DOLConfigBridge.saveTextureCacheToState()
    viSkip = DOLConfigBridge.viSkip()
    gpuTextureDecoding = DOLConfigBridge.gpuTextureDecoding()
    textureCacheAccuracy = Int(DOLConfigBridge.textureCacheAccuracy())
    forceProgressiveScan = DOLConfigBridge.forceProgressiveScan()
    disableCopyToVRAM = DOLConfigBridge.disableCopyToVRAM()
    copyEFBScaled = DOLConfigBridge.copyEFBScaled()
    fastTextureSampling = DOLConfigBridge.fastTextureSampling()
    noMipmapping = DOLConfigBridge.noMipmapping()
    
    textureFiltering = Int(DOLConfigBridge.textureFiltering())
    anisotropicFiltering = Int(DOLConfigBridge.anisotropicFiltering())
    ssaa = DOLConfigBridge.ssaa()
    pixelLighting = DOLConfigBridge.pixelLighting()
    forceTrueColor = DOLConfigBridge.forceTrueColor()
    disableCopyFilter = DOLConfigBridge.disableCopyFilter()
    arbitraryMipmapDetection = DOLConfigBridge.arbitraryMipmapDetection()
    disableFog = DOLConfigBridge.disableFog()
    outputResampling = Int(DOLConfigBridge.outputResampling())
    hdrOutput = DOLConfigBridge.hdrOutput()
    exposure = DOLConfigBridge.exposure()
    cacheHiresTextures = DOLConfigBridge.cacheHiresTextures()
    arbitraryMipmapDetectionThreshold = DOLConfigBridge.arbitraryMipmapDetectionThreshold()
    postProcessingShader = DOLConfigBridge.postProcessingShader() ?? ""
    
    pauseOnPanic = DOLConfigBridge.pauseOnPanic()
    precisionFrameTiming = DOLConfigBridge.precisionFrameTiming()
    viOverclockEnable = DOLConfigBridge.viOverclockEnable()
    viOverclock = DOLConfigBridge.viOverclock()
    dspHLE = DOLConfigBridge.dspHLE()
    syncGPU = DOLConfigBridge.syncGPU()
    fastDiscSpeed = DOLConfigBridge.fastDiscSpeed()
    overclockEnable = DOLConfigBridge.overclockEnable()
    overclock = DOLConfigBridge.overclock()
    mmu = DOLConfigBridge.mmu()
    audioLatency = Int(DOLConfigBridge.audioLatency())
    skipIPL = DOLConfigBridge.skipIPL()
    gcLanguage = Int(DOLConfigBridge.gcLanguage())
    
    audioVolume = Int(DOLConfigBridge.audioVolume())
    dpl2Decoder = DOLConfigBridge.dpl2Decoder()
    preferSpatialAudio = DOLConfigBridge.preferSpatialAudio()
    audioOutputMode = min(Int(DOLConfigBridge.audioOutputMode()), 2)
    audioUpsampling = DOLConfigBridge.audioUpsampling()
    audioStretch = DOLConfigBridge.audioStretch()
    audioBufferSize = Int(DOLConfigBridge.audioBufferSize())
    audioBackend = DOLConfigBridge.audioBackend()
    audioMuted = DOLConfigBridge.audioMuted()
    
    useGameCovers = DOLConfigBridge.useGameCovers()
    confirmOnStop = DOLConfigBridge.confirmOnStop()
    panicHandlers = DOLConfigBridge.panicHandlers()
    osdMessages = DOLConfigBridge.osdMessages()
    skipNKitWarning = DOLConfigBridge.skipNKitWarning()
    pauseWhenInMenu = DOLConfigBridge.pauseWhenInMenu()
    abortOnPanicAlert = DOLConfigBridge.abortOnPanicAlert()
    cheatsEnabled = DOLConfigBridge.cheatsEnabled()
    
    enableSavestates = DOLConfigBridge.enableSavestates()
    rewindEnabled = DOLConfigBridge.rewindEnabled()
    
    fastmem = DOLConfigBridge.fastmem()
    mismatchedRegionSettings = DOLConfigBridge.mismatchedRegionSettings()
    autoDiscChange = DOLConfigBridge.autoDiscChange()
    
    bellAudioEnabled = DOLConfigBridge.bellAudioEnabled()
    bellAudioAdaptiveBuffering = DOLConfigBridge.bellAudioAdaptiveBuffering()
    bellAudioNEONMixing = DOLConfigBridge.bellAudioNEONMixing()
    bellAudioDrivenPacing = DOLConfigBridge.bellAudioDrivenPacing()
    bellAudioUnderrunProtection = DOLConfigBridge.bellAudioUnderrunProtection()
    bellAudioDynamicRateCorrection = DOLConfigBridge.bellAudioDynamicRateCorrection()
    bellAudioHQProcessing = DOLConfigBridge.bellAudioHQProcessing()
    
    wiiProgressiveScan = DOLConfigBridge.wiiProgressiveScan()
    
    touchPadOpacity = DOLConfigBridge.touchPadOpacity()
    touchPadIRMode = Int(DOLConfigBridge.touchPadIRMode())
    muteSwitchMode = Int(DOLConfigBridge.muteSwitchMode())
  }
}

// MARK: - Computed Properties for UI

extension ConfigBridge {
  /// Returns emulation speed as percentage (0 = unlimited)
  var emulationSpeedPercent: Int {
    get { Int(emulationSpeed * 100) }
    set { emulationSpeed = Float(newValue) / 100.0 }
  }
  
  /// Human-readable emulation speed string
  var emulationSpeedDisplay: String {
    if emulationSpeed == 0 {
      return "Unlimited"
    } else {
      return "\(Int(emulationSpeed * 100))%"
    }
  }
  
  /// Human-readable MetalFX resolution string (always 1.25x internal)
  var metalFXResolutionDisplay: String {
    return "1.25× Internal"
  }
  
  // Legacy - kept for compatibility but unused
  var _metalFXResolutionDisplayLegacy: String {
    if metalFXOutputWidth <= 0 && metalFXOutputHeight <= 0 {
      return "Native"
    }
    return "\(metalFXOutputWidth)×\(metalFXOutputHeight)"
  }
  
  /// Human-readable interpreter cache size string
  var interpreterCacheSizeDisplay: String {
    return "\(interpreterCacheSize) MB"
  }
}

// MARK: - Shared MSAA options (in-game menu + Settings)

/// Single source of truth for MSAA options and labels. Used by EmulationView game menu and CPUSettingsView.
/// Backend: MTLUtil.mm fills AAModes from [device supportsTextureSampleCount:i]. VideoConfig::VerifyValidity() clamps if unsupported.
enum MSAAOptions {
  /// (Display string, config value). 1 = Off; 2/4/8 = 2x/4x/8x MSAA. Kept to 8 max for compatibility (16/32 not reliable on some devices).
  static let all: [(String, Int)] = [
    ("Off", 1),
    ("2x MSAA", 2),
    ("4x MSAA (heavy)", 4),
    ("8x MSAA (heavy)", 8),
  ]
  
  /// Label for a given sample count (for display when you only have the Int, e.g. view model).
  static func label(for samples: Int) -> String {
    if samples <= 1 { return "Off" }
    if samples >= 4 { return "\(samples)x MSAA (heavy)" }
    return "\(samples)x MSAA"
  }
}

// MARK: - Setting Info Button & Row

struct SettingInfoButton: View {
  let info: String
  @State private var showing = false

  var body: some View {
    Button {
      showing = true
    } label: {
      Image(systemName: "info.circle")
        .foregroundColor(.secondary)
        .font(.system(size: 14))
    }
    .buttonStyle(.plain)
    .alert("Info", isPresented: $showing) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(info)
    }
  }
}

struct SettingRow: View {
  let title: String
  let info: String?
  let isOn: Binding<Bool>

  init(_ title: String, isOn: Binding<Bool>, info: String? = nil) {
    self.title = title
    self.info = info
    self.isOn = isOn
  }

  var body: some View {
    HStack {
      Toggle(title, isOn: isOn)
      if let info {
        SettingInfoButton(info: info)
      }
    }
  }
}

