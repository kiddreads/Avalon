// Copyright 2008 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#ifdef IPHONEOS
#include <AudioUnit/AudioUnit.h>
#endif

#include <vector>
#include "AudioCommon/SoundStream.h"

// Output mode constants (shared with .cpp)
static constexpr int OUTPUT_MODE_MONO = 0;
static constexpr int OUTPUT_MODE_STEREO = 1;
static constexpr int OUTPUT_MODE_SURROUND = 2;

class CoreAudioSound final : public SoundStream
{
#ifdef IPHONEOS
public:
  bool Init() override;
  bool SetRunning(bool running) override;
  void SetVolume(int volume) override;

  static bool IsValid() { return true; }

private:
  AudioUnit audio_unit;
  int m_volume;
  UInt32 m_actual_channels = 2;  // channels actually in use (from stream format after Init)
  int m_output_mode = OUTPUT_MODE_STEREO;  // Cached output mode (RT-safe, no Config::Get in callback)
  bool m_use_neon_mixing = false;  // Cached Bell Audio NEON mixing flag (RT-safe)
  bool m_underrun_protection = false;  // Cached Bell Audio underrun protection flag (RT-safe)
  bool m_dynamic_rate_correction = false;  // Cached Bell Audio dynamic rate correction flag (RT-safe)
  bool m_hq_processing = false;  // Cached Bell Audio HQ processing flag (RT-safe)

  // Bell Audio: HQ processing - DC offset removal state (first-order high-pass at ~5Hz)
  float m_dc_prev_in_l = 0.0f;
  float m_dc_prev_in_r = 0.0f;
  float m_dc_prev_out_l = 0.0f;
  float m_dc_prev_out_r = 0.0f;

  // Bell Audio: HQ processing - TPDF dithering PRNG state
  uint32_t m_dither_state = 0x12345678;

  // Bell Audio: Underrun protection - soft-mute envelope to avoid pops/clicks
  float m_underrun_envelope = 1.0f;  // Current envelope level (1.0 = full, 0.0 = silent)
  int m_underrun_count = 0;  // Consecutive underrun callbacks

  // Bell Audio: Dynamic rate correction - micro-adjust sample consumption rate
  float m_rate_correction = 1.0f;  // Current rate multiplier (1.0 = nominal)
  float m_rate_correction_ema = 0.5f;  // EMA of buffer fill ratio

  // Pre-allocated buffers for RT callback (no malloc/resize in callback)
  static constexpr size_t MAX_FRAMES_PER_CALLBACK = 4096;  // Reasonable upper bound
  std::vector<float> m_surround_buffer;  // MAX_FRAMES_PER_CALLBACK * 6
  std::vector<short> m_stereo_tmp_buffer;  // MAX_FRAMES_PER_CALLBACK * 2
  std::vector<short> m_deinterleave_tmp_buffer;  // MAX_FRAMES_PER_CALLBACK * 2

  static OSStatus callback(void* ref_con, AudioUnitRenderActionFlags* action_flags,
                           const AudioTimeStamp* timestamp, UInt32 bus_number, UInt32 number_frames,
                           AudioBufferList* io_data);
#endif
};
