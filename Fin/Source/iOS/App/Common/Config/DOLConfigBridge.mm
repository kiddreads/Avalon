// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "DOLConfigBridge.h"

#include <algorithm>

#import "Core/Config/GraphicsSettings.h"
#import "Core/Config/MainSettings.h"
#import "Core/Config/SYSCONFSettings.h"
#import "Core/Config/UISettings.h"
#import "Core/Config/iOSSettings.h"
#import "Core/ConfigManager.h"
#import "Core/PowerPC/PowerPC.h"

#import "Common/Config/Config.h"
#import "Common/FileUtil.h"

#import "VideoCommon/VideoConfig.h"

#import "Core/TimePlayed.h"
#import "FoundationStringUtil.h"

namespace {
template<typename InfoT, typename ValueT>
void SetAndSave(const Config::Info<InfoT>& info, const ValueT& value) {
  Config::SetBaseOrCurrent(info, value);
  Config::Save();
}
template<typename InfoT, typename ValueT>
void SetBaseAndSave(const Config::Info<InfoT>& info, const ValueT& value) {
  Config::SetBase(info, value);
  Config::Save();
}
}

@implementation DOLConfigBridge

+ (void)saveConfig
{
  Config::Save();
}

// MARK: - Main/Core Settings

+ (BOOL)dualCore {
  return Config::Get(Config::MAIN_CPU_THREAD);
}

+ (void)setDualCore:(BOOL)value {
  SetAndSave(Config::MAIN_CPU_THREAD, (bool)value);
}

+ (BOOL)idleSkip {
  return Config::Get(Config::MAIN_SYNC_ON_SKIP_IDLE);
}

+ (void)setIdleSkip:(BOOL)value {
  SetAndSave(Config::MAIN_SYNC_ON_SKIP_IDLE, (bool)value);
}

+ (BOOL)cheatsEnabled {
  return Config::Get(Config::MAIN_ENABLE_CHEATS);
}

+ (void)setCheatsEnabled:(BOOL)value {
  SetAndSave(Config::MAIN_ENABLE_CHEATS, (bool)value);
}

+ (float)emulationSpeed {
  return Config::Get(Config::MAIN_EMULATION_SPEED);
}

+ (void)setEmulationSpeed:(float)value {
  SetAndSave(Config::MAIN_EMULATION_SPEED, value);
}

+ (int)interpreterCacheSize {
  return Config::Get(Config::MAIN_CACHED_INTERPRETER_CODE_REGION_SIZE_MB);
}

+ (void)setInterpreterCacheSize:(int)value {
  SetAndSave(Config::MAIN_CACHED_INTERPRETER_CODE_REGION_SIZE_MB, value);
}

+ (int)cpuCore {
  auto core = Config::Get(Config::MAIN_CPU_CORE);
  switch (core) {
    case PowerPC::CPUCore::Interpreter: return 0;
    case PowerPC::CPUCore::CachedInterpreter: return 1;
    case PowerPC::CPUCore::InlineCachedInterpreter: return 2;
    default: return 1;
  }
}

+ (void)setCpuCore:(int)value {
  PowerPC::CPUCore core;
  switch (value) {
    case 0: core = PowerPC::CPUCore::Interpreter; break;
    case 2: core = PowerPC::CPUCore::InlineCachedInterpreter; break;
    default: core = PowerPC::CPUCore::CachedInterpreter; break;
  }
  SetAndSave(Config::MAIN_CPU_CORE, core);
}

// MARK: - Graphics Settings

+ (BOOL)useGPUVertexDecode {
  return Config::Get(Config::GFX_MTL_GPU_VERTEX_DECODE);
}
+ (void)setUseGPUVertexDecode:(BOOL)value {
  SetAndSave(Config::GFX_MTL_GPU_VERTEX_DECODE, (bool)value);
}

// Native Video Decode (iOS)
+ (BOOL)useNativeVideoDecode {
  return Config::Get(Config::GFX_USE_NATIVE_VIDEO_DECODE);
}
+ (void)setUseNativeVideoDecode:(BOOL)value {
  SetAndSave(Config::GFX_USE_NATIVE_VIDEO_DECODE, (bool)value);
}

// MetalFX Upscaling - wired to Dolphin Config system
+ (BOOL)metalFXUpscaling {
  return Config::Get(Config::GFX_MTL_FX_UPSCALING);
}
+ (void)setMetalFXUpscaling:(BOOL)value {
  SetAndSave(Config::GFX_MTL_FX_UPSCALING, (bool)value);
}

+ (int)metalFXOutputWidth {
  int width = Config::Get(Config::GFX_MTL_FX_OUTPUT_WIDTH);
  return width > 0 ? width : 1920;
}
+ (void)setMetalFXOutputWidth:(int)value {
  SetAndSave(Config::GFX_MTL_FX_OUTPUT_WIDTH, value);
}

+ (int)metalFXOutputHeight {
  int height = Config::Get(Config::GFX_MTL_FX_OUTPUT_HEIGHT);
  return height > 0 ? height : 1080;
}
+ (void)setMetalFXOutputHeight:(int)value {
  SetAndSave(Config::GFX_MTL_FX_OUTPUT_HEIGHT, value);
}

+ (BOOL)metalFXOutput125xInternal {
  return Config::Get(Config::GFX_MTL_FX_OUTPUT_125X_INTERNAL);
}
+ (void)setMetalFXOutput125xInternal:(BOOL)value {
  SetAndSave(Config::GFX_MTL_FX_OUTPUT_125X_INTERNAL, (bool)value);
}

+ (int)metalFXInternalScale {
  int scale = Config::Get(Config::GFX_MTL_FX_INTERNAL_SCALE);
  return scale > 0 ? scale : 50;
}
+ (void)setMetalFXInternalScale:(int)value {
  SetAndSave(Config::GFX_MTL_FX_INTERNAL_SCALE, value);
}

+ (int)internalResolution {
  return Config::Get(Config::GFX_EFB_SCALE);
}

+ (void)setInternalResolution:(int)value {
  SetAndSave(Config::GFX_EFB_SCALE, value);
}

+ (void)setInternalResolutionLive:(int)value {
  Config::SetCurrent(Config::GFX_EFB_SCALE, value);
}

+ (BOOL)widescreen {
  return Config::Get(Config::GFX_WIDESCREEN_HACK);
}

+ (void)setWidescreen:(BOOL)value {
  SetAndSave(Config::GFX_WIDESCREEN_HACK, (bool)value);
}

+ (BOOL)vsync {
  return Config::Get(Config::GFX_VSYNC);
}

+ (void)setVsync:(BOOL)value {
  SetAndSave(Config::GFX_VSYNC, (bool)value);
}

+ (BOOL)graphicsMods {
  return Config::Get(Config::GFX_MODS_ENABLE);
}

+ (void)setGraphicsMods:(BOOL)value {
  SetAndSave(Config::GFX_MODS_ENABLE, (bool)value);
}

+ (BOOL)showFPS {
  return Config::Get(Config::GFX_SHOW_FPS);
}

+ (void)setShowFPS:(BOOL)value {
  SetAndSave(Config::GFX_SHOW_FPS, (bool)value);
}

+ (BOOL)showSpeed {
  return Config::Get(Config::GFX_SHOW_SPEED);
}

+ (void)setShowSpeed:(BOOL)value {
  SetAndSave(Config::GFX_SHOW_SPEED, (bool)value);
}

+ (BOOL)backendMultithreading {
  return Config::Get(Config::GFX_BACKEND_MULTITHREADING);
}

+ (void)setBackendMultithreading:(BOOL)value {
  SetAndSave(Config::GFX_BACKEND_MULTITHREADING, (bool)value);
}

+ (BOOL)loadCustomTextures {
  return Config::Get(Config::GFX_HIRES_TEXTURES);
}

+ (void)setLoadCustomTextures:(BOOL)value {
  SetAndSave(Config::GFX_HIRES_TEXTURES, (bool)value);
}

+ (int)aspectRatio {
  return (int)Config::Get(Config::GFX_ASPECT_RATIO);
}

+ (void)setAspectRatio:(int)value {
  SetAndSave(Config::GFX_ASPECT_RATIO, (AspectMode)value);
}

+ (void)setAspectRatioLive:(int)value {
  Config::SetCurrent(Config::GFX_ASPECT_RATIO, (AspectMode)value);
  g_Config.aspect_mode = (AspectMode)value;
  g_ActiveConfig.aspect_mode = (AspectMode)value;
}

+ (int)msaa {
  return (int)Config::Get(Config::GFX_MSAA);
}

+ (void)setMsaa:(int)value {
  // MSAA 1 = off (no multisampling). Ensure we never store 0.
  SetAndSave(Config::GFX_MSAA, (u32)std::max(1, value));
}

+ (void)setMsaaLive:(int)value {
  Config::SetCurrent(Config::GFX_MSAA, (u32)std::max(1, value));
}

+ (int)shaderCompilationMode {
  return (int)Config::Get(Config::GFX_SHADER_COMPILATION_MODE);
}

+ (void)setShaderCompilationMode:(int)value {
  SetAndSave(Config::GFX_SHADER_COMPILATION_MODE, (ShaderCompilationMode)value);
}

+ (long long)playTimeSecondsForGameID:(NSString*)gameID {
  if (!gameID.length) return 0;
  TimePlayed tp;
  auto ms = tp.GetTimePlayed(FoundationToCppString(gameID));
  return static_cast<long long>(ms.count() / 1000);
}

// MARK: - EFB/Performance Hacks

+ (BOOL)skipEFBAccess {
  return !Config::Get(Config::GFX_HACK_EFB_ACCESS_ENABLE);
}

+ (void)setSkipEFBAccess:(BOOL)value {
  SetAndSave(Config::GFX_HACK_EFB_ACCESS_ENABLE, (bool)!value);
}

+ (BOOL)skipEFBCopyToRAM {
  return Config::Get(Config::GFX_HACK_SKIP_EFB_COPY_TO_RAM);
}

+ (void)setSkipEFBCopyToRAM:(BOOL)value {
  SetAndSave(Config::GFX_HACK_SKIP_EFB_COPY_TO_RAM, (bool)value);
}

+ (BOOL)deferEFBCopies {
  return Config::Get(Config::GFX_HACK_DEFER_EFB_COPIES);
}

+ (void)setDeferEFBCopies:(BOOL)value {
  SetAndSave(Config::GFX_HACK_DEFER_EFB_COPIES, (bool)value);
}

+ (BOOL)deferEFBInvalidation {
  return Config::Get(Config::GFX_HACK_EFB_DEFER_INVALIDATION);
}

+ (void)setDeferEFBInvalidation:(BOOL)value {
  SetAndSave(Config::GFX_HACK_EFB_DEFER_INVALIDATION, (bool)value);
}

+ (BOOL)immediateXFB {
  return Config::Get(Config::GFX_HACK_IMMEDIATE_XFB);
}

+ (void)setImmediateXFB:(BOOL)value {
  SetAndSave(Config::GFX_HACK_IMMEDIATE_XFB, (bool)value);
}

+ (BOOL)efbEmulateFormatChanges {
  return Config::Get(Config::GFX_HACK_EFB_EMULATE_FORMAT_CHANGES);
}

+ (void)setEfbEmulateFormatChanges:(BOOL)value {
  SetAndSave(Config::GFX_HACK_EFB_EMULATE_FORMAT_CHANGES, (bool)value);
}

+ (BOOL)skipXFBCopyToRAM {
  return Config::Get(Config::GFX_HACK_SKIP_XFB_COPY_TO_RAM);
}

+ (void)setSkipXFBCopyToRAM:(BOOL)value {
  SetAndSave(Config::GFX_HACK_SKIP_XFB_COPY_TO_RAM, (bool)value);
}

+ (BOOL)skipDuplicateXFBs {
  return Config::Get(Config::GFX_HACK_SKIP_DUPLICATE_XFBS);
}

+ (void)setSkipDuplicateXFBs:(BOOL)value {
  SetAndSave(Config::GFX_HACK_SKIP_DUPLICATE_XFBS, (bool)value);
}

+ (BOOL)earlyXFBOutput {
  return Config::Get(Config::GFX_HACK_EARLY_XFB_OUTPUT);
}

+ (void)setEarlyXFBOutput:(BOOL)value {
  SetAndSave(Config::GFX_HACK_EARLY_XFB_OUTPUT, (bool)value);
}

+ (BOOL)fastDepthCalc {
  return Config::Get(Config::GFX_FAST_DEPTH_CALC);
}

+ (void)setFastDepthCalc:(BOOL)value {
  SetAndSave(Config::GFX_FAST_DEPTH_CALC, (bool)value);
}

+ (BOOL)vertexRounding {
  return Config::Get(Config::GFX_HACK_VERTEX_ROUNDING);
}

+ (void)setVertexRounding:(BOOL)value {
  SetAndSave(Config::GFX_HACK_VERTEX_ROUNDING, (bool)value);
}

+ (BOOL)boundingBoxEnable {
  return Config::Get(Config::GFX_HACK_BBOX_ENABLE);
}

+ (void)setBoundingBoxEnable:(BOOL)value {
  SetAndSave(Config::GFX_HACK_BBOX_ENABLE, (bool)value);
}

+ (BOOL)saveTextureCacheToState {
  return Config::Get(Config::GFX_SAVE_TEXTURE_CACHE_TO_STATE);
}

+ (void)setSaveTextureCacheToState:(BOOL)value {
  SetAndSave(Config::GFX_SAVE_TEXTURE_CACHE_TO_STATE, (bool)value);
}

+ (BOOL)viSkip {
  return Config::Get(Config::GFX_HACK_VI_SKIP);
}

+ (void)setViSkip:(BOOL)value {
  SetAndSave(Config::GFX_HACK_VI_SKIP, (bool)value);
}

+ (BOOL)gpuTextureDecoding {
  return Config::Get(Config::GFX_ENABLE_GPU_TEXTURE_DECODING);
}

+ (void)setGpuTextureDecoding:(BOOL)value {
  SetAndSave(Config::GFX_ENABLE_GPU_TEXTURE_DECODING, (bool)value);
}

+ (int)textureCacheAccuracy {
  return Config::Get(Config::GFX_SAFE_TEXTURE_CACHE_COLOR_SAMPLES);
}

+ (void)setTextureCacheAccuracy:(int)value {
  SetAndSave(Config::GFX_SAFE_TEXTURE_CACHE_COLOR_SAMPLES, value);
}

// MARK: - Audio Settings

+ (int)audioVolume {
  return Config::Get(Config::MAIN_AUDIO_VOLUME);
}

+ (void)setAudioVolume:(int)value {
  SetAndSave(Config::MAIN_AUDIO_VOLUME, value);
}

+ (BOOL)audioStretch {
  return Config::Get(Config::MAIN_AUDIO_FILL_GAPS);
}

+ (void)setAudioStretch:(BOOL)value {
  SetAndSave(Config::MAIN_AUDIO_FILL_GAPS, (bool)value);
}

+ (int)audioBufferSize {
  return Config::Get(Config::MAIN_AUDIO_BUFFER_SIZE);
}

+ (void)setAudioBufferSize:(int)value {
  SetAndSave(Config::MAIN_AUDIO_BUFFER_SIZE, value);
}

+ (NSString *)audioBackend {
  return CppToFoundationString(Config::Get(Config::MAIN_AUDIO_BACKEND));
}

+ (void)setAudioBackend:(NSString *)value {
  SetAndSave(Config::MAIN_AUDIO_BACKEND, FoundationToCppString(value));
}

+ (BOOL)audioMuted {
  return Config::Get(Config::MAIN_AUDIO_MUTED);
}

+ (void)setAudioMuted:(BOOL)value {
  SetAndSave(Config::MAIN_AUDIO_MUTED, (bool)value);
}

+ (BOOL)dpl2Decoder {
  return Config::Get(Config::MAIN_DPL2_DECODER);
}

+ (void)setDpl2Decoder:(BOOL)value {
  SetAndSave(Config::MAIN_DPL2_DECODER, (bool)value);
}

+ (BOOL)preferSpatialAudio {
  return Config::Get(Config::MAIN_PREFER_SPATIAL_AUDIO);
}

+ (void)setPreferSpatialAudio:(BOOL)value {
  SetAndSave(Config::MAIN_PREFER_SPATIAL_AUDIO, (bool)value);
}

+ (int)audioOutputMode {
  return Config::Get(Config::MAIN_AUDIO_OUTPUT_MODE);
}

+ (void)setAudioOutputMode:(int)value {
  SetAndSave(Config::MAIN_AUDIO_OUTPUT_MODE, value);
}

+ (BOOL)audioUpsampling {
  return Config::Get(Config::MAIN_AUDIO_UPSAMPLING);
}

+ (void)setAudioUpsampling:(BOOL)value {
  SetAndSave(Config::MAIN_AUDIO_UPSAMPLING, (bool)value);
}

// MARK: - Interface Settings

+ (BOOL)useGameCovers {
  return Config::Get(Config::MAIN_USE_GAME_COVERS);
}

+ (void)setUseGameCovers:(BOOL)value {
  SetBaseAndSave(Config::MAIN_USE_GAME_COVERS, (bool)value);
}

+ (BOOL)confirmOnStop {
  return Config::Get(Config::MAIN_CONFIRM_ON_STOP);
}

+ (void)setConfirmOnStop:(BOOL)value {
  SetBaseAndSave(Config::MAIN_CONFIRM_ON_STOP, (bool)value);
}

+ (BOOL)panicHandlers {
  return Config::Get(Config::MAIN_USE_PANIC_HANDLERS);
}

+ (void)setPanicHandlers:(BOOL)value {
  SetBaseAndSave(Config::MAIN_USE_PANIC_HANDLERS, (bool)value);
}

+ (BOOL)osdMessages {
  return Config::Get(Config::MAIN_OSD_MESSAGES);
}

+ (void)setOsdMessages:(BOOL)value {
  SetBaseAndSave(Config::MAIN_OSD_MESSAGES, (bool)value);
}

+ (BOOL)skipNKitWarning {
  return Config::Get(Config::MAIN_SKIP_NKIT_WARNING);
}

+ (void)setSkipNKitWarning:(BOOL)value {
  SetBaseAndSave(Config::MAIN_SKIP_NKIT_WARNING, (bool)value);
}

+ (BOOL)abortOnPanicAlert {
  return Config::Get(Config::MAIN_ABORT_ON_PANIC_ALERT);
}

+ (void)setAbortOnPanicAlert:(BOOL)value {
  SetBaseAndSave(Config::MAIN_ABORT_ON_PANIC_ALERT, (bool)value);
}

// MARK: - Bell Audio (Experimental iOS Audio Improvements)

+ (BOOL)bellAudioEnabled {
  return Config::Get(Config::MAIN_BELL_AUDIO_ENABLED);
}

+ (void)setBellAudioEnabled:(BOOL)value {
  SetBaseAndSave(Config::MAIN_BELL_AUDIO_ENABLED, (bool)value);
}

+ (BOOL)bellAudioAdaptiveBuffering {
  return Config::Get(Config::MAIN_BELL_AUDIO_ADAPTIVE_BUFFERING);
}

+ (void)setBellAudioAdaptiveBuffering:(BOOL)value {
  SetBaseAndSave(Config::MAIN_BELL_AUDIO_ADAPTIVE_BUFFERING, (bool)value);
}

+ (BOOL)bellAudioNEONMixing {
  return Config::Get(Config::MAIN_BELL_AUDIO_NEON_MIXING);
}

+ (void)setBellAudioNEONMixing:(BOOL)value {
  SetBaseAndSave(Config::MAIN_BELL_AUDIO_NEON_MIXING, (bool)value);
}

+ (BOOL)bellAudioDrivenPacing {
  return Config::Get(Config::MAIN_BELL_AUDIO_DRIVEN_PACING);
}

+ (void)setBellAudioDrivenPacing:(BOOL)value {
  SetBaseAndSave(Config::MAIN_BELL_AUDIO_DRIVEN_PACING, (bool)value);
}

+ (BOOL)bellAudioUnderrunProtection {
  return Config::Get(Config::MAIN_BELL_AUDIO_UNDERRUN_PROTECTION);
}

+ (void)setBellAudioUnderrunProtection:(BOOL)value {
  SetBaseAndSave(Config::MAIN_BELL_AUDIO_UNDERRUN_PROTECTION, (bool)value);
}

+ (BOOL)bellAudioDynamicRateCorrection {
  return Config::Get(Config::MAIN_BELL_AUDIO_DYNAMIC_RATE_CORRECTION);
}

+ (void)setBellAudioDynamicRateCorrection:(BOOL)value {
  SetBaseAndSave(Config::MAIN_BELL_AUDIO_DYNAMIC_RATE_CORRECTION, (bool)value);
}

+ (BOOL)bellAudioHQProcessing {
  return Config::Get(Config::MAIN_BELL_AUDIO_HQ_PROCESSING);
}

+ (void)setBellAudioHQProcessing:(BOOL)value {
  SetBaseAndSave(Config::MAIN_BELL_AUDIO_HQ_PROCESSING, (bool)value);
}

// MARK: - Advanced/Experimental Settings

+ (BOOL)fastmem {
  return Config::Get(Config::MAIN_FASTMEM);
}

+ (void)setFastmem:(BOOL)value {
  SetAndSave(Config::MAIN_FASTMEM, (bool)value);
}

+ (BOOL)mismatchedRegionSettings {
  return Config::Get(Config::MAIN_OVERRIDE_REGION_SETTINGS);
}

+ (void)setMismatchedRegionSettings:(BOOL)value {
  SetAndSave(Config::MAIN_OVERRIDE_REGION_SETTINGS, (bool)value);
}

+ (BOOL)autoDiscChange {
  return Config::Get(Config::MAIN_AUTO_DISC_CHANGE);
}

+ (void)setAutoDiscChange:(BOOL)value {
  SetBaseAndSave(Config::MAIN_AUTO_DISC_CHANGE, (bool)value);
}

// MARK: - Wii Settings

+ (BOOL)wiiProgressiveScan {
  return Config::Get(Config::SYSCONF_PROGRESSIVE_SCAN);
}

+ (void)setWiiProgressiveScan:(BOOL)value {
  SetBaseAndSave(Config::SYSCONF_PROGRESSIVE_SCAN, (bool)value);
}

// MARK: - Controller Settings

+ (float)touchPadOpacity {
  return Config::Get(Config::MAIN_TOUCH_PAD_OPACITY);
}

+ (void)setTouchPadOpacity:(float)value {
  SetAndSave(Config::MAIN_TOUCH_PAD_OPACITY, value);
}

+ (int)touchPadIRMode {
  return Config::Get(Config::MAIN_TOUCH_PAD_IR_MODE);
}

+ (void)setTouchPadIRMode:(int)value {
  SetAndSave(Config::MAIN_TOUCH_PAD_IR_MODE, value);
}

+ (int)muteSwitchMode {
  return Config::Get(Config::MAIN_MUTE_SWITCH_MODE);
}

+ (void)setMuteSwitchMode:(int)value {
  SetAndSave(Config::MAIN_MUTE_SWITCH_MODE, value);
}

+ (BOOL)pauseWhenInMenu {
  return Config::Get(Config::MAIN_PAUSE_WHEN_IN_MENU);
}

+ (void)setPauseWhenInMenu:(BOOL)value {
  SetAndSave(Config::MAIN_PAUSE_WHEN_IN_MENU, (bool)value);
}

+ (BOOL)rewindEnabled {
  return Config::Get(Config::MAIN_REWIND_ENABLED);
}

+ (void)setRewindEnabled:(BOOL)value {
  SetAndSave(Config::MAIN_REWIND_ENABLED, (bool)value);
}

// MARK: - State Settings

+ (int)selectedStateSlot {
  return Config::GetBase(Config::MAIN_SELECTED_STATE_SLOT);
}

+ (void)setSelectedStateSlot:(int)value {
  SetBaseAndSave(Config::MAIN_SELECTED_STATE_SLOT, value);
}

+ (BOOL)enableSavestates {
  return Config::Get(Config::MAIN_ENABLE_SAVESTATES);
}

+ (void)setEnableSavestates:(BOOL)value {
  SetAndSave(Config::MAIN_ENABLE_SAVESTATES, (bool)value);
}

// MARK: - Skylanders

+ (BOOL)emulateSkylanderPortal {
  return Config::Get(Config::MAIN_EMULATE_SKYLANDER_PORTAL);
}

// MARK: - Current Game Info

+ (NSString *)currentGameID {
  return CppToFoundationString(SConfig::GetInstance().GetGameID());
}

+ (NSString *)currentGameTDBID {
  return CppToFoundationString(SConfig::GetInstance().GetGameTDBID());
}

+ (int)currentGameRevision {
  return (int)SConfig::GetInstance().GetRevision();
}

// MARK: - Additional Graphics Enhancements

+ (int)textureFiltering {
  return (int)Config::Get(Config::GFX_ENHANCE_FORCE_TEXTURE_FILTERING);
}

+ (void)setTextureFiltering:(int)value {
  SetAndSave(Config::GFX_ENHANCE_FORCE_TEXTURE_FILTERING, (TextureFilteringMode)value);
}

+ (int)anisotropicFiltering {
  return (int)Config::Get(Config::GFX_ENHANCE_MAX_ANISOTROPY);
}

+ (void)setAnisotropicFiltering:(int)value {
  SetAndSave(Config::GFX_ENHANCE_MAX_ANISOTROPY, (AnisotropicFilteringMode)value);
}

+ (BOOL)ssaa {
  return Config::Get(Config::GFX_SSAA);
}

+ (void)setSsaa:(BOOL)value {
  SetAndSave(Config::GFX_SSAA, (bool)value);
}

+ (BOOL)pixelLighting {
  return Config::Get(Config::GFX_ENABLE_PIXEL_LIGHTING);
}

+ (void)setPixelLighting:(BOOL)value {
  SetAndSave(Config::GFX_ENABLE_PIXEL_LIGHTING, (bool)value);
}

+ (BOOL)forceTrueColor {
  return Config::Get(Config::GFX_ENHANCE_FORCE_TRUE_COLOR);
}

+ (void)setForceTrueColor:(BOOL)value {
  SetAndSave(Config::GFX_ENHANCE_FORCE_TRUE_COLOR, (bool)value);
}

+ (BOOL)disableCopyFilter {
  return Config::Get(Config::GFX_ENHANCE_DISABLE_COPY_FILTER);
}

+ (void)setDisableCopyFilter:(BOOL)value {
  SetAndSave(Config::GFX_ENHANCE_DISABLE_COPY_FILTER, (bool)value);
}

+ (BOOL)arbitraryMipmapDetection {
  return Config::Get(Config::GFX_ENHANCE_ARBITRARY_MIPMAP_DETECTION);
}

+ (void)setArbitraryMipmapDetection:(BOOL)value {
  SetAndSave(Config::GFX_ENHANCE_ARBITRARY_MIPMAP_DETECTION, (bool)value);
}

+ (BOOL)disableFog {
  return Config::Get(Config::GFX_DISABLE_FOG);
}

+ (void)setDisableFog:(BOOL)value {
  SetAndSave(Config::GFX_DISABLE_FOG, (bool)value);
}

+ (int)outputResampling {
  return static_cast<int>(Config::Get(Config::GFX_ENHANCE_OUTPUT_RESAMPLING));
}

+ (void)setOutputResampling:(int)value {
  SetAndSave(Config::GFX_ENHANCE_OUTPUT_RESAMPLING,
                           static_cast<OutputResamplingMode>(value));
}

+ (NSString *)postProcessingShader {
  std::string s = Config::Get(Config::GFX_ENHANCE_POST_SHADER);
  return s.empty() ? @"" : CppToFoundationString(s);
}

+ (void)setPostProcessingShader:(NSString *)value {
  std::string s = value ? FoundationToCppString(value) : std::string();
  SetAndSave(Config::GFX_ENHANCE_POST_SHADER, s);
}

+ (NSString *)shadersDirectoryPath {
  std::string path = File::GetUserPath(D_SHADERS_IDX);
  if (path.empty())
    return nil;
  return CppToFoundationString(path);
}

+ (BOOL)hdrOutput {
  return Config::Get(Config::GFX_ENHANCE_HDR_OUTPUT);
}

+ (void)setHdrOutput:(BOOL)value {
  SetAndSave(Config::GFX_ENHANCE_HDR_OUTPUT, (bool)value);
}

+ (float)exposure {
  return Config::Get(Config::GFX_CC_EXPOSURE);
}

+ (void)setExposure:(float)value {
  SetAndSave(Config::GFX_CC_EXPOSURE, value);
}

+ (BOOL)cacheHiresTextures {
  return Config::Get(Config::GFX_CACHE_HIRES_TEXTURES);
}

+ (void)setCacheHiresTextures:(BOOL)value {
  SetAndSave(Config::GFX_CACHE_HIRES_TEXTURES, (bool)value);
}

+ (float)arbitraryMipmapDetectionThreshold {
  return Config::Get(Config::GFX_ENHANCE_ARBITRARY_MIPMAP_DETECTION_THRESHOLD);
}

+ (void)setArbitraryMipmapDetectionThreshold:(float)value {
  SetAndSave(Config::GFX_ENHANCE_ARBITRARY_MIPMAP_DETECTION_THRESHOLD, value);
}

// MARK: - Additional Graphics Hacks

+ (BOOL)forceProgressiveScan {
  return Config::Get(Config::GFX_HACK_FORCE_PROGRESSIVE);
}

+ (void)setForceProgressiveScan:(BOOL)value {
  SetAndSave(Config::GFX_HACK_FORCE_PROGRESSIVE, (bool)value);
}

+ (BOOL)disableCopyToVRAM {
  return Config::Get(Config::GFX_HACK_DISABLE_COPY_TO_VRAM);
}

+ (void)setDisableCopyToVRAM:(BOOL)value {
  SetAndSave(Config::GFX_HACK_DISABLE_COPY_TO_VRAM, (bool)value);
}

+ (BOOL)copyEFBScaled {
  return Config::Get(Config::GFX_HACK_COPY_EFB_SCALED);
}

+ (void)setCopyEFBScaled:(BOOL)value {
  SetAndSave(Config::GFX_HACK_COPY_EFB_SCALED, (bool)value);
}

+ (BOOL)fastTextureSampling {
  return Config::Get(Config::GFX_HACK_FAST_TEXTURE_SAMPLING);
}

+ (void)setFastTextureSampling:(BOOL)value {
  SetAndSave(Config::GFX_HACK_FAST_TEXTURE_SAMPLING, (bool)value);
}

+ (BOOL)noMipmapping {
#ifdef __APPLE__
  return Config::Get(Config::GFX_HACK_NO_MIPMAPPING);
#else
  return false;
#endif
}

+ (void)setNoMipmapping:(BOOL)value {
#ifdef __APPLE__
  SetAndSave(Config::GFX_HACK_NO_MIPMAPPING, (bool)value);
#endif
}

// MARK: - Additional Core Settings (mainline parity)

+ (BOOL)pauseOnPanic {
  return Config::Get(Config::MAIN_PAUSE_ON_PANIC);
}

+ (void)setPauseOnPanic:(BOOL)value {
  SetAndSave(Config::MAIN_PAUSE_ON_PANIC, (bool)value);
}

+ (BOOL)precisionFrameTiming {
  return Config::Get(Config::MAIN_PRECISION_FRAME_TIMING);
}

+ (void)setPrecisionFrameTiming:(BOOL)value {
  SetAndSave(Config::MAIN_PRECISION_FRAME_TIMING, (bool)value);
}

+ (BOOL)viOverclockEnable {
  return Config::Get(Config::MAIN_VI_OVERCLOCK_ENABLE);
}

+ (void)setViOverclockEnable:(BOOL)value {
  SetAndSave(Config::MAIN_VI_OVERCLOCK_ENABLE, (bool)value);
}

+ (float)viOverclock {
  return Config::Get(Config::MAIN_VI_OVERCLOCK);
}

+ (void)setViOverclock:(float)value {
  SetAndSave(Config::MAIN_VI_OVERCLOCK, value);
}

// MARK: - DSP / Core

+ (BOOL)dspHLE {
  return Config::Get(Config::MAIN_DSP_HLE);
}

+ (void)setDspHLE:(BOOL)value {
  SetAndSave(Config::MAIN_DSP_HLE, (bool)value);
}

+ (BOOL)syncGPU {
  return Config::Get(Config::MAIN_SYNC_GPU);
}

+ (void)setSyncGPU:(BOOL)value {
  SetAndSave(Config::MAIN_SYNC_GPU, (bool)value);
}

+ (BOOL)fastDiscSpeed {
  return Config::Get(Config::MAIN_FAST_DISC_SPEED);
}

+ (void)setFastDiscSpeed:(BOOL)value {
  SetAndSave(Config::MAIN_FAST_DISC_SPEED, (bool)value);
}

+ (BOOL)overclockEnable {
  return Config::Get(Config::MAIN_OVERCLOCK_ENABLE);
}

+ (void)setOverclockEnable:(BOOL)value {
  SetAndSave(Config::MAIN_OVERCLOCK_ENABLE, (bool)value);
}

+ (float)overclock {
  return Config::Get(Config::MAIN_OVERCLOCK);
}

+ (void)setOverclock:(float)value {
  SetAndSave(Config::MAIN_OVERCLOCK, value);
}

+ (BOOL)mmu {
  return Config::Get(Config::MAIN_MMU);
}

+ (void)setMmu:(BOOL)value {
  SetAndSave(Config::MAIN_MMU, (bool)value);
}

+ (int)audioLatency {
  return Config::Get(Config::MAIN_AUDIO_LATENCY);
}

+ (void)setAudioLatency:(int)value {
  SetAndSave(Config::MAIN_AUDIO_LATENCY, value);
}

+ (BOOL)skipIPL {
  return Config::Get(Config::MAIN_SKIP_IPL);
}

+ (void)setSkipIPL:(BOOL)value {
  SetAndSave(Config::MAIN_SKIP_IPL, (bool)value);
}

+ (int)gcLanguage {
  return Config::Get(Config::MAIN_GC_LANGUAGE);
}

+ (void)setGcLanguage:(int)value {
  SetAndSave(Config::MAIN_GC_LANGUAGE, value);
}

@end
