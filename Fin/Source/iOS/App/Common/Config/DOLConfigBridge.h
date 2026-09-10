// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge for Dolphin's C++ Config system.
/// Allows Swift code to read/write configuration values.
@interface DOLConfigBridge : NSObject

// MARK: - Main/Core Settings

// CPU
+ (BOOL)dualCore;
+ (void)setDualCore:(BOOL)value;

+ (BOOL)idleSkip;
+ (void)setIdleSkip:(BOOL)value;

+ (BOOL)cheatsEnabled;
+ (void)setCheatsEnabled:(BOOL)value;

+ (float)emulationSpeed;
+ (void)setEmulationSpeed:(float)value;

+ (int)interpreterCacheSize;
+ (void)setInterpreterCacheSize:(int)value;

/// CPU core: 0 = Interpreter, 1 = Cached Interpreter, 2 = Inline Cached Interpreter
+ (int)cpuCore;
+ (void)setCpuCore:(int)value;

// MARK: - Graphics Settings

+ (BOOL)useNativeVideoDecode;
+ (void)setUseNativeVideoDecode:(BOOL)value;

+ (BOOL)useGPUVertexDecode;
+ (void)setUseGPUVertexDecode:(BOOL)value;

+ (BOOL)metalFXUpscaling;
+ (void)setMetalFXUpscaling:(BOOL)value;

+ (int)metalFXOutputWidth;
+ (void)setMetalFXOutputWidth:(int)value;

+ (int)metalFXOutputHeight;
+ (void)setMetalFXOutputHeight:(int)value;

+ (BOOL)metalFXOutput125xInternal;
+ (void)setMetalFXOutput125xInternal:(BOOL)value;

+ (int)metalFXInternalScale;
+ (void)setMetalFXInternalScale:(int)value;

+ (int)internalResolution;
+ (void)setInternalResolution:(int)value;

/// Set internal resolution immediately (for live updates during gameplay)
+ (void)setInternalResolutionLive:(int)value;

+ (BOOL)widescreen;
+ (void)setWidescreen:(BOOL)value;

+ (BOOL)vsync;
+ (void)setVsync:(BOOL)value;

+ (BOOL)graphicsMods;
+ (void)setGraphicsMods:(BOOL)value;

+ (BOOL)showFPS;
+ (void)setShowFPS:(BOOL)value;

+ (BOOL)showSpeed;
+ (void)setShowSpeed:(BOOL)value;

+ (BOOL)backendMultithreading;
+ (void)setBackendMultithreading:(BOOL)value;

+ (BOOL)loadCustomTextures;
+ (void)setLoadCustomTextures:(BOOL)value;

+ (int)aspectRatio;
+ (void)setAspectRatio:(int)value;
+ (void)setAspectRatioLive:(int)value;

+ (int)msaa;
+ (void)setMsaa:(int)value;
+ (void)setMsaaLive:(int)value;

/// Shader Compilation Mode (0=Sync, 1=Sync+Uber, 2=Async+Uber, 3=Async+Skip)
+ (int)shaderCompilationMode;
+ (void)setShaderCompilationMode:(int)value;

/// Returns total play time in seconds for the given game ID (e.g. from GameFile), or 0 if none.
+ (long long)playTimeSecondsForGameID:(NSString*)gameID;

// MARK: - EFB/Performance Hacks

/// Skip EFB Access - disables CPU reads of EFB (can break collision/effects in some games)
+ (BOOL)skipEFBAccess;
+ (void)setSkipEFBAccess:(BOOL)value;

/// Skip EFB Copy to RAM - keeps EFB copies on GPU (can break some effects)
+ (BOOL)skipEFBCopyToRAM;
+ (void)setSkipEFBCopyToRAM:(BOOL)value;

/// Defer EFB Copies - batch EFB copies to reduce stalls
+ (BOOL)deferEFBCopies;
+ (void)setDeferEFBCopies:(BOOL)value;

/// Defer EFB Invalidation - reduce cache invalidations
+ (BOOL)deferEFBInvalidation;
+ (void)setDeferEFBInvalidation:(BOOL)value;

/// Immediate XFB - present without full EFB sync (can cause tearing)
+ (BOOL)immediateXFB;
+ (void)setImmediateXFB:(BOOL)value;

/// EFB Emulate Format Changes - accurately handle format changes (disable = Ignore Format Changes)
+ (BOOL)efbEmulateFormatChanges;
+ (void)setEfbEmulateFormatChanges:(BOOL)value;

/// Skip XFB Copy to RAM - keeps XFB copies on GPU (Store XFB Copies to Texture Only)
+ (BOOL)skipXFBCopyToRAM;
+ (void)setSkipXFBCopyToRAM:(BOOL)value;

/// Skip Duplicate XFBs - skip presenting duplicate frames
+ (BOOL)skipDuplicateXFBs;
+ (void)setSkipDuplicateXFBs:(BOOL)value;

/// Early XFB Output (mainline: GFX_HACK_EARLY_XFB_OUTPUT)
+ (BOOL)earlyXFBOutput;
+ (void)setEarlyXFBOutput:(BOOL)value;

/// Fast Depth Calculation
+ (BOOL)fastDepthCalc;
+ (void)setFastDepthCalc:(BOOL)value;

/// Vertex Rounding - rounds vertices to whole pixels
+ (BOOL)vertexRounding;
+ (void)setVertexRounding:(BOOL)value;

/// Bounding Box Enable - disable for performance (inverted in UI)
+ (BOOL)boundingBoxEnable;
+ (void)setBoundingBoxEnable:(BOOL)value;

/// Save Texture Cache to State
+ (BOOL)saveTextureCacheToState;
+ (void)setSaveTextureCacheToState:(BOOL)value;

/// VI Skip - skip vertical blank interrupts
+ (BOOL)viSkip;
+ (void)setViSkip:(BOOL)value;

/// GPU Texture Decoding
+ (BOOL)gpuTextureDecoding;
+ (void)setGpuTextureDecoding:(BOOL)value;

/// Texture Cache Accuracy (0 = Safe, 512 = Medium, 128 = Fast)
+ (int)textureCacheAccuracy;
+ (void)setTextureCacheAccuracy:(int)value;

// MARK: - Audio Settings

+ (int)audioVolume;
+ (void)setAudioVolume:(int)value;

+ (BOOL)audioStretch;
+ (void)setAudioStretch:(BOOL)value;

+ (int)audioBufferSize;
+ (void)setAudioBufferSize:(int)value;

+ (NSString *)audioBackend;
+ (void)setAudioBackend:(NSString *)value;

/// Mute audio (mainline: MAIN_AUDIO_MUTED)
+ (BOOL)audioMuted;
+ (void)setAudioMuted:(BOOL)value;

/// Surround (DPL2) decoding for richer stereo (iOS)
+ (BOOL)dpl2Decoder;
+ (void)setDpl2Decoder:(BOOL)value;

/// Prefer spatial audio on compatible hardware (AirPods Pro etc.)
+ (BOOL)preferSpatialAudio;
+ (void)setPreferSpatialAudio:(BOOL)value;

/// Audio output mode: 0 = Mono, 1 = Stereo, 2 = Surround (6ch)
+ (int)audioOutputMode;
+ (void)setAudioOutputMode:(int)value;

/// Audio upsampling (96 kHz output when enabled)
+ (BOOL)audioUpsampling;
+ (void)setAudioUpsampling:(BOOL)value;

// MARK: - Interface Settings

+ (BOOL)useGameCovers;
+ (void)setUseGameCovers:(BOOL)value;

+ (BOOL)confirmOnStop;
+ (void)setConfirmOnStop:(BOOL)value;

+ (BOOL)panicHandlers;
+ (void)setPanicHandlers:(BOOL)value;

+ (BOOL)osdMessages;
+ (void)setOsdMessages:(BOOL)value;

+ (BOOL)skipNKitWarning;
+ (void)setSkipNKitWarning:(BOOL)value;

+ (BOOL)abortOnPanicAlert;
+ (void)setAbortOnPanicAlert:(BOOL)value;

// MARK: - Bell Audio (Experimental iOS Audio Improvements)

+ (BOOL)bellAudioEnabled;
+ (void)setBellAudioEnabled:(BOOL)value;

+ (BOOL)bellAudioAdaptiveBuffering;
+ (void)setBellAudioAdaptiveBuffering:(BOOL)value;

+ (BOOL)bellAudioNEONMixing;
+ (void)setBellAudioNEONMixing:(BOOL)value;

+ (BOOL)bellAudioDrivenPacing;
+ (void)setBellAudioDrivenPacing:(BOOL)value;

+ (BOOL)bellAudioUnderrunProtection;
+ (void)setBellAudioUnderrunProtection:(BOOL)value;

+ (BOOL)bellAudioDynamicRateCorrection;
+ (void)setBellAudioDynamicRateCorrection:(BOOL)value;

+ (BOOL)bellAudioHQProcessing;
+ (void)setBellAudioHQProcessing:(BOOL)value;

// MARK: - Advanced/Experimental Settings

+ (BOOL)fastmem;
+ (void)setFastmem:(BOOL)value;

+ (BOOL)mismatchedRegionSettings;
+ (void)setMismatchedRegionSettings:(BOOL)value;

+ (BOOL)autoDiscChange;
+ (void)setAutoDiscChange:(BOOL)value;

// MARK: - Wii Settings

+ (BOOL)wiiProgressiveScan;
+ (void)setWiiProgressiveScan:(BOOL)value;

// MARK: - Controller Settings

+ (float)touchPadOpacity;
+ (void)setTouchPadOpacity:(float)value;

/// iOS: Mute switch mode (0=off, 1=follow hardware mute, etc.)
+ (int)muteSwitchMode;
+ (void)setMuteSwitchMode:(int)value;

/// Pause emulation when the in-game menu is open
+ (BOOL)pauseWhenInMenu;
+ (void)setPauseWhenInMenu:(BOOL)value;

/// Enable rewind (periodic save states to slots 10/11)
+ (BOOL)rewindEnabled;
+ (void)setRewindEnabled:(BOOL)value;

+ (int)touchPadIRMode;
+ (void)setTouchPadIRMode:(int)value;

// MARK: - State Settings

+ (int)selectedStateSlot;
+ (void)setSelectedStateSlot:(int)value;

/// Enable save/load state (mainline: MAIN_ENABLE_SAVESTATES)
+ (BOOL)enableSavestates;
+ (void)setEnableSavestates:(BOOL)value;

// MARK: - Skylanders

+ (BOOL)emulateSkylanderPortal;

// MARK: - Current Game Info (for cheats/gecko codes)

/// Returns the current running game's ID (e.g., "GXPE78")
+ (NSString *)currentGameID;

/// Returns the current running game's GameTDB ID
+ (NSString *)currentGameTDBID;

/// Returns the current running game's revision
+ (int)currentGameRevision;

/// Persist all config to disk. Call when the user leaves Settings or the in-game menu.
+ (void)saveConfig;

// MARK: - Additional Graphics Enhancements

/// Force Texture Filtering (0=Auto, 1=Force Nearest, 2=Force Linear)
+ (int)textureFiltering;
+ (void)setTextureFiltering:(int)value;

/// Anisotropic Filtering (0=Auto/Default, 1=1x, 2=2x, 3=4x, 4=8x, 5=16x)
+ (int)anisotropicFiltering;
+ (void)setAnisotropicFiltering:(int)value;

/// SSAA (Super-Sampled Anti-Aliasing)
+ (BOOL)ssaa;
+ (void)setSsaa:(BOOL)value;

/// Per-Pixel Lighting
+ (BOOL)pixelLighting;
+ (void)setPixelLighting:(BOOL)value;

/// Force True Color
+ (BOOL)forceTrueColor;
+ (void)setForceTrueColor:(BOOL)value;

/// Disable Copy Filter
+ (BOOL)disableCopyFilter;
+ (void)setDisableCopyFilter:(BOOL)value;

/// Arbitrary Mipmap Detection
+ (BOOL)arbitraryMipmapDetection;
+ (void)setArbitraryMipmapDetection:(BOOL)value;

/// Disable Fog
+ (BOOL)disableFog;
+ (void)setDisableFog:(BOOL)value;

/// Output resampling mode (0=Default, 1=Bilinear, 2=BSpline, 3=MitchellNetravali, 4=CatmullRom, 5=SharpBilinear, 6=AreaSampling)
+ (int)outputResampling;
+ (void)setOutputResampling:(int)value;

/// Post-processing shader name (e.g. "Anime4K" for Anime4K.glsl). Empty string = none.
+ (NSString *)postProcessingShader;
+ (void)setPostProcessingShader:(NSString *)value;

/// Path to the Shaders folder where .glsl files are loaded from. Nil if user path not set.
+ (NSString *)shadersDirectoryPath;

/// HDR output (when display supports it)
+ (BOOL)hdrOutput;
+ (void)setHdrOutput:(BOOL)value;

/// Exposure for HDR/tone mapping (1.0 = no adjustment). Used by post-processing.
+ (float)exposure;
+ (void)setExposure:(float)value;

/// Cache custom textures to disk
+ (BOOL)cacheHiresTextures;
+ (void)setCacheHiresTextures:(BOOL)value;

/// Arbitrary mipmap detection threshold (e.g. 14.0)
+ (float)arbitraryMipmapDetectionThreshold;
+ (void)setArbitraryMipmapDetectionThreshold:(float)value;

// MARK: - Additional Graphics Hacks

/// Force Progressive Scan
+ (BOOL)forceProgressiveScan;
+ (void)setForceProgressiveScan:(BOOL)value;

/// Disable Copy to VRAM
+ (BOOL)disableCopyToVRAM;
+ (void)setDisableCopyToVRAM:(BOOL)value;

/// Copy EFB Scaled
+ (BOOL)copyEFBScaled;
+ (void)setCopyEFBScaled:(BOOL)value;

/// Fast Texture Sampling
+ (BOOL)fastTextureSampling;
+ (void)setFastTextureSampling:(BOOL)value;

/// No Mipmapping (Apple)
+ (BOOL)noMipmapping;
+ (void)setNoMipmapping:(BOOL)value;

// MARK: - Additional Core Settings (mainline parity)

/// Pause emulation on panic (mainline: MAIN_PAUSE_ON_PANIC)
+ (BOOL)pauseOnPanic;
+ (void)setPauseOnPanic:(BOOL)value;

/// Precision frame timing (mainline: MAIN_PRECISION_FRAME_TIMING)
+ (BOOL)precisionFrameTiming;
+ (void)setPrecisionFrameTiming:(BOOL)value;

/// VI (Video Interface) overclock enable (mainline: MAIN_VI_OVERCLOCK_ENABLE)
+ (BOOL)viOverclockEnable;
+ (void)setViOverclockEnable:(BOOL)value;

/// VI overclock factor (1.0 = 100%, mainline: MAIN_VI_OVERCLOCK)
+ (float)viOverclock;
+ (void)setViOverclock:(float)value;

// MARK: - DSP / Core

/// DSP HLE vs LLE
+ (BOOL)dspHLE;
+ (void)setDspHLE:(BOOL)value;

/// Sync GPU
+ (BOOL)syncGPU;
+ (void)setSyncGPU:(BOOL)value;

/// Fast Disc Speed
+ (BOOL)fastDiscSpeed;
+ (void)setFastDiscSpeed:(BOOL)value;

/// Overclock Enable
+ (BOOL)overclockEnable;
+ (void)setOverclockEnable:(BOOL)value;

/// Overclock Percentage (1.0 = 100%)
+ (float)overclock;
+ (void)setOverclock:(float)value;

/// MMU (Memory Management Unit)
+ (BOOL)mmu;
+ (void)setMmu:(BOOL)value;

/// Audio Latency (ms)
+ (int)audioLatency;
+ (void)setAudioLatency:(int)value;

/// Skip IPL (Boot to game directly)
+ (BOOL)skipIPL;
+ (void)setSkipIPL:(BOOL)value;

/// GC Language
+ (int)gcLanguage;
+ (void)setGcLanguage:(int)value;

@end

NS_ASSUME_NONNULL_END
