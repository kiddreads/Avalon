// Copyright 2008 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include <AudioUnit/AudioUnit.h>
#include <cmath>
#include <cstring>
#include <vector>

#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>
#endif

#include "AudioCommon/CoreAudioSoundStream.h"
#include "Common/Logging/Log.h"
#include "Core/Config/MainSettings.h"
#ifdef IPHONEOS
#include "Core/Config/iOSSettings.h"
#endif
#include <string>

// NEON-optimized float to s16 conversion helpers (Bell Audio)
#if defined(__ARM_NEON) || defined(__aarch64__)
static void ConvertFloatToS16_NEON(const float* src, short* dst, size_t count)
{
  const float32x4_t scale = vdupq_n_f32(32767.0f);
  const float32x4_t min_val = vdupq_n_f32(-1.0f);
  const float32x4_t max_val = vdupq_n_f32(1.0f);
  
  size_t i = 0;
  for (; i + 7 < count; i += 8)
  {
    float32x4_t v0 = vld1q_f32(src + i);
    float32x4_t v1 = vld1q_f32(src + i + 4);
    
    // Clamp to [-1, 1]
    v0 = vmaxq_f32(vminq_f32(v0, max_val), min_val);
    v1 = vmaxq_f32(vminq_f32(v1, max_val), min_val);
    
    // Scale and convert to s16
    v0 = vmulq_f32(v0, scale);
    v1 = vmulq_f32(v1, scale);
    
    int32x4_t i0 = vcvtq_s32_f32(v0);
    int32x4_t i1 = vcvtq_s32_f32(v1);
    
    int16x4_t s0 = vqmovn_s32(i0);
    int16x4_t s1 = vqmovn_s32(i1);
    
    vst1q_s16(dst + i, vcombine_s16(s0, s1));
  }
  
  // Handle remaining samples
  for (; i < count; i++)
  {
    float v = std::clamp(src[i], -1.0f, 1.0f);
    dst[i] = static_cast<short>(v * 32767.f);
  }
}

static void DownmixSurroundToStereo_NEON(const float* surround, short* left, short* right, size_t frames)
{
  const float fc_coeff = 0.707f;
  const float lfe_coeff = 0.5f;
  const float scale = 32767.0f;
  
  // NEON downmix is complex for 6ch->2ch, so use scalar for now (still faster than full scalar path due to float->s16 conversion)
  // The main benefit is in the 6ch float->s16 conversion which is already optimized
  for (size_t i = 0; i < frames; i++)
  {
    const float* s = surround + i * 6;
    float l = s[0] + fc_coeff * s[2] + fc_coeff * s[4] + lfe_coeff * s[3];
    float r = s[1] + fc_coeff * s[2] + fc_coeff * s[5] + lfe_coeff * s[3];
    l = std::clamp(l, -1.0f, 1.0f);
    r = std::clamp(r, -1.0f, 1.0f);
    left[i] = static_cast<short>(l * scale);
    right[i] = static_cast<short>(r * scale);
  }
}
#endif  // NEON

OSStatus CoreAudioSound::callback(void* ref_con, AudioUnitRenderActionFlags* action_flags,
                                  const AudioTimeStamp* timestamp, UInt32 bus_number,
                                  UInt32 number_frames, AudioBufferList* io_data)
{
  auto* const sound = static_cast<CoreAudioSound*>(ref_con);
  // RT-safe: use cached output mode instead of Config::Get
  const int output_mode = sound->m_output_mode;
  
  // RT-safe: check Bell Audio NEON mixing (cached at Init, not checked in callback)
  const bool use_neon = sound->m_use_neon_mixing;

  // RT-safe: bounds check to prevent buffer overrun
  if (number_frames > MAX_FRAMES_PER_CALLBACK)
  {
    ERROR_LOG_FMT(AUDIO, "Audio callback requested {} frames, max is {}", number_frames,
                  MAX_FRAMES_PER_CALLBACK);
    return noErr;
  }

  if (output_mode == OUTPUT_MODE_SURROUND)
  {
    // Surround: 6ch when device supports it, else downmix to stereo to avoid overflow/distortion.
    // RT-safe: use pre-allocated buffer (no resize/malloc)
    const size_t need = number_frames * 6;
    float* surround_buf = sound->m_surround_buffer.data();
    const size_t got = sound->m_mixer->MixSurround(surround_buf, number_frames);
    if (got != number_frames)
      return noErr;
    const UInt32 buf_bytes = io_data->mBuffers[0].mDataByteSize;
    const bool can_output_6ch =
        (sound->m_actual_channels >= 6 && buf_bytes >= number_frames * 6 * sizeof(short));
    short* out = static_cast<short*>(io_data->mBuffers[0].mData);
    if (can_output_6ch)
    {
#if defined(__ARM_NEON) || defined(__aarch64__)
      if (use_neon)
      {
        // NEON-optimized: convert 6ch float to s16
        for (UInt32 i = 0; i < number_frames; i++)
        {
          ConvertFloatToS16_NEON(surround_buf + i * 6, out + i * 6, 6);
        }
      }
      else
#endif
      {
        // Scalar fallback
        for (UInt32 i = 0; i < number_frames; i++)
        {
          const float* s = surround_buf + i * 6;
          for (int ch = 0; ch < 6; ch++)
          {
            float v = std::clamp(s[ch], -1.0f, 1.0f);
            out[i * 6 + ch] = static_cast<short>(v * 32767.f);
          }
        }
      }
    }
    else
    {
      // Downmix 5.1 to stereo: L = FL + 0.707*FC + 0.707*BL + 0.5*LFE, R = FR + 0.707*FC + 0.707*BR + 0.5*LFE
      short* buf0 = static_cast<short*>(io_data->mBuffers[0].mData);
      short* buf1 = (io_data->mNumberBuffers > 1) ? static_cast<short*>(io_data->mBuffers[1].mData) : nullptr;
#if defined(__ARM_NEON) || defined(__aarch64__)
      if (use_neon && buf1)
      {
        // NEON-optimized downmix to planar stereo
        DownmixSurroundToStereo_NEON(surround_buf, buf0, buf1, number_frames);
      }
      else
#endif
      {
        // Scalar fallback
        for (UInt32 i = 0; i < number_frames; i++)
        {
          const float* s = surround_buf + i * 6;
          float l = s[0] + 0.707f * s[2] + 0.707f * s[4] + 0.5f * s[3];
          float r = s[1] + 0.707f * s[2] + 0.707f * s[5] + 0.5f * s[3];
          l = std::clamp(l, -1.0f, 1.0f);
          r = std::clamp(r, -1.0f, 1.0f);
          short ls = static_cast<short>(l * 32767.f);
          short rs = static_cast<short>(r * 32767.f);
          if (buf1)
          {
            buf0[i] = ls;
            buf1[i] = rs;
          }
          else
          {
            buf0[i * 2] = ls;
            buf0[i * 2 + 1] = rs;
          }
        }
      }
    }
    return noErr;
  }

  if (output_mode == OUTPUT_MODE_MONO)
  {
    // RT-safe: use pre-allocated buffer
    // Mix() expects frame count (stereo pairs), not individual samples
    short* stereo_tmp = sound->m_stereo_tmp_buffer.data();
    const size_t mixed = sound->m_mixer->Mix(stereo_tmp, number_frames);
    if (mixed != number_frames)
      return noErr;
    short* out = static_cast<short*>(io_data->mBuffers[0].mData);
    for (UInt32 i = 0; i < number_frames; i++)
    {
      float m = (stereo_tmp[i * 2] + stereo_tmp[i * 2 + 1]) * 0.5f / 32768.f;
      out[i] = static_cast<short>(std::clamp(m, -1.0f, 1.0f) * 32767.f);
    }
    return noErr;
  }

  // Stereo: single Mix into interleaved L,R; proper mapping for planar (2 buffers) or interleaved (1 buffer).
  // Mix() expects frame count (stereo pairs), not individual samples
  short* ptr = static_cast<short*>(io_data->mBuffers[0].mData);
  sound->m_mixer->Mix(ptr, number_frames);

  // Bell Audio: Underrun protection - smooth fade-out/fade-in envelope to avoid pops/clicks
  // when the mixer buffer is starving. Also applies dynamic rate correction envelope.
  const bool underrun_prot = sound->m_underrun_protection;
  const bool dyn_rate = sound->m_dynamic_rate_correction;
  if (underrun_prot || dyn_rate)
  {
    const float fill_ratio = sound->m_mixer->GetBufferFillRatio();

    // Update EMA of fill ratio (smoothing factor ~0.05 for stability)
    constexpr float ema_alpha = 0.05f;
    sound->m_rate_correction_ema += ema_alpha * (fill_ratio - sound->m_rate_correction_ema);
    const float ema = sound->m_rate_correction_ema;

    // Underrun protection: detect starvation and apply envelope
    if (underrun_prot)
    {
      // If buffer is critically low (< 15%), fade out; otherwise fade in
      constexpr float underrun_threshold = 0.15f;
      constexpr float recovery_threshold = 0.25f;
      constexpr float fade_out_speed = 0.002f;  // ~500 callbacks to full silence (smooth)
      constexpr float fade_in_speed = 0.005f;   // ~200 callbacks to full volume

      if (ema < underrun_threshold)
      {
        sound->m_underrun_count++;
        // Rapid fade-out: exponential decay toward 0
        sound->m_underrun_envelope *= (1.0f - fade_out_speed * 10.0f);
        if (sound->m_underrun_envelope < 0.001f)
          sound->m_underrun_envelope = 0.0f;
      }
      else if (ema > recovery_threshold)
      {
        sound->m_underrun_count = 0;
        // Smooth fade-in back to full volume
        sound->m_underrun_envelope += fade_in_speed * (1.0f - sound->m_underrun_envelope);
        if (sound->m_underrun_envelope > 0.999f)
          sound->m_underrun_envelope = 1.0f;
      }

      // Apply envelope to all samples if not at full volume
      if (sound->m_underrun_envelope < 0.999f)
      {
        const float env = sound->m_underrun_envelope;
        for (UInt32 i = 0; i < number_frames * 2; i++)
        {
          ptr[i] = static_cast<short>(ptr[i] * env);
        }
      }
    }

    // Dynamic rate correction: micro-adjust playback to keep buffer at target fill
    // When buffer is low, we slightly attenuate (effectively "stretching" what we have)
    // When buffer is high, we leave samples at full amplitude (normal consumption)
    // This works in concert with audio-driven frame pacing in CoreTiming
    if (dyn_rate)
    {
      constexpr float target_fill = 0.5f;
      constexpr float max_correction = 0.015f;  // ±1.5% max rate adjustment
      const float error = ema - target_fill;

      // Smooth correction: proportional to error
      float correction = 1.0f;
      if (error < -0.15f)
      {
        // Buffer getting low - apply gentle volume ramp down at tail to signal stretch
        // This creates a subtle "slow down" effect on the audio side
        correction = 1.0f + max_correction;  // Slightly boost to compensate for upcoming gap
      }
      else if (error > 0.15f)
      {
        // Buffer getting full - slightly reduce to help drain
        correction = 1.0f - max_correction;
      }
      else
      {
        // Proportional zone
        correction = 1.0f - (error / 0.15f) * max_correction;
      }

      sound->m_rate_correction = correction;

      // Apply subtle per-sample rate correction envelope (only when not near 1.0)
      if (correction < 0.998f || correction > 1.002f)
      {
        for (UInt32 i = 0; i < number_frames * 2; i++)
        {
          float s = ptr[i] * correction;
          ptr[i] = static_cast<short>(std::clamp(s, -32768.0f, 32767.0f));
        }
      }
    }
  }

  // Bell Audio: HQ processing - soft clipping, TPDF dithering, DC offset removal
  // Applied per-sample on the final s16 stereo buffer for maximum quality
  if (sound->m_hq_processing)
  {
    // DC offset removal coefficient: first-order high-pass at ~5Hz
    // y[n] = x[n] - x[n-1] + R * y[n-1], R = 1 - (2*pi*fc/fs)
    // At 48kHz, fc=5Hz: R ≈ 0.99935
    constexpr float dc_R = 0.99935f;

    for (UInt32 i = 0; i < number_frames; i++)
    {
      // Read current samples as float [-1, 1]
      float l = ptr[i * 2] / 32768.0f;
      float r = ptr[i * 2 + 1] / 32768.0f;

      // 1) DC offset removal (high-pass filter)
      float dc_out_l = l - sound->m_dc_prev_in_l + dc_R * sound->m_dc_prev_out_l;
      float dc_out_r = r - sound->m_dc_prev_in_r + dc_R * sound->m_dc_prev_out_r;
      sound->m_dc_prev_in_l = l;
      sound->m_dc_prev_in_r = r;
      sound->m_dc_prev_out_l = dc_out_l;
      sound->m_dc_prev_out_r = dc_out_r;
      l = dc_out_l;
      r = dc_out_r;

      // 2) Soft clipping via fast tanh approximation (Pade approximant)
      // tanh(x) ≈ x * (27 + x^2) / (27 + 9*x^2) for |x| < 3
      // This gives a warm, musical saturation on peaks instead of harsh digital clipping
      auto fast_tanh = [](float x) -> float {
        if (x > 3.0f) return 1.0f;
        if (x < -3.0f) return -1.0f;
        const float x2 = x * x;
        return x * (27.0f + x2) / (27.0f + 9.0f * x2);
      };
      l = fast_tanh(l);
      r = fast_tanh(r);

      // 3) TPDF dithering: add triangular-distributed noise before quantization
      // This eliminates quantization distortion harmonics, replacing them with
      // a flat noise floor ~6dB below the s16 LSB — perceptually much cleaner
      // PRNG: xorshift32 (fast, RT-safe, no division)
      auto xorshift32 = [](uint32_t& state) -> uint32_t {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return state;
      };
      // Two uniform random values → triangular distribution via subtraction
      const float rnd1 = static_cast<float>(static_cast<int32_t>(xorshift32(sound->m_dither_state))) / 2147483648.0f;
      const float rnd2 = static_cast<float>(static_cast<int32_t>(xorshift32(sound->m_dither_state))) / 2147483648.0f;
      const float tpdf = (rnd1 - rnd2) * (1.0f / 32768.0f);  // ±1 LSB triangular noise

      // Scale to s16 range and add dither before rounding
      float l_out = l * 32767.0f + tpdf;
      float r_out = r * 32767.0f + tpdf;

      // Final quantization with clamping
      ptr[i * 2] = static_cast<short>(std::clamp(std::lround(l_out), -32768L, 32767L));
      ptr[i * 2 + 1] = static_cast<short>(std::clamp(std::lround(r_out), -32768L, 32767L));
    }
  }

  if (io_data->mNumberBuffers > 1)
  {
    short* buf0 = static_cast<short*>(io_data->mBuffers[0].mData);
    short* buf1 = static_cast<short*>(io_data->mBuffers[1].mData);
    // RT-safe: use pre-allocated buffer
    short* deinterleave_tmp = sound->m_deinterleave_tmp_buffer.data();
    std::memcpy(deinterleave_tmp, buf0, number_frames * 2 * sizeof(short));
    for (UInt32 i = 0; i < number_frames; i++)
    {
      buf0[i] = deinterleave_tmp[i * 2];
      buf1[i] = deinterleave_tmp[i * 2 + 1];
    }
  }
  return noErr;
}

bool CoreAudioSound::Init()
{
  OSStatus err;
  AURenderCallbackStruct callback_struct;
  AudioStreamBasicDescription format;
  AudioComponentDescription desc;
  AudioComponent component;

  desc.componentType = kAudioUnitType_Output;
  desc.componentSubType = kAudioUnitSubType_RemoteIO;
  desc.componentFlags = 0;
  desc.componentFlagsMask = 0;
  desc.componentManufacturer = kAudioUnitManufacturer_Apple;
  component = AudioComponentFindNext(nullptr, &desc);
  if (component == nullptr)
  {
    ERROR_LOG_FMT(AUDIO, "error finding audio component");
    return false;
  }

  err = AudioComponentInstanceNew(component, &audio_unit);
  if (err != noErr)
  {
    ERROR_LOG_FMT(AUDIO, "error opening audio component");
    return false;
  }

  // Cache output mode for RT-safe callback (no Config::Get in callback)
  m_output_mode = Config::Get(Config::MAIN_AUDIO_OUTPUT_MODE);
  // Cache Bell Audio NEON mixing flag (RT-safe)
  // Enabled when Bell backend is selected OR when explicitly enabled
#ifdef IPHONEOS
  const std::string backend = Config::Get(Config::MAIN_AUDIO_BACKEND);
#ifdef BACKEND_BELL
  const bool is_bell_backend = (backend == BACKEND_BELL);
#else
  const bool is_bell_backend = (backend == "Bell");
#endif
  m_use_neon_mixing = (is_bell_backend && Config::Get(Config::MAIN_BELL_AUDIO_NEON_MIXING)) ||
                      (!is_bell_backend && Config::Get(Config::MAIN_BELL_AUDIO_ENABLED) &&
                       Config::Get(Config::MAIN_BELL_AUDIO_NEON_MIXING));
  m_underrun_protection = (is_bell_backend || Config::Get(Config::MAIN_BELL_AUDIO_ENABLED)) &&
                          Config::Get(Config::MAIN_BELL_AUDIO_UNDERRUN_PROTECTION);
  m_dynamic_rate_correction = (is_bell_backend || Config::Get(Config::MAIN_BELL_AUDIO_ENABLED)) &&
                              Config::Get(Config::MAIN_BELL_AUDIO_DYNAMIC_RATE_CORRECTION);
  m_hq_processing = (is_bell_backend || Config::Get(Config::MAIN_BELL_AUDIO_ENABLED)) &&
                    Config::Get(Config::MAIN_BELL_AUDIO_HQ_PROCESSING);
#else
  m_use_neon_mixing = false;
  m_underrun_protection = false;
  m_dynamic_rate_correction = false;
  m_hq_processing = false;
#endif
  UInt32 channels = (m_output_mode == OUTPUT_MODE_SURROUND) ? 6 : (m_output_mode == OUTPUT_MODE_MONO) ? 1 : 2;
  FillOutASBDForLPCM(format, m_mixer->GetSampleRate(), channels, 16, 16, false, false, false);

  // Pre-allocate buffers for RT callback (no malloc/resize in callback)
  m_surround_buffer.resize(MAX_FRAMES_PER_CALLBACK * 6);
  m_stereo_tmp_buffer.resize(MAX_FRAMES_PER_CALLBACK * 2);
  m_deinterleave_tmp_buffer.resize(MAX_FRAMES_PER_CALLBACK * 2);
  err = AudioUnitSetProperty(audio_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                             &format, sizeof(AudioStreamBasicDescription));
  if (err != noErr)
  {
    ERROR_LOG_FMT(AUDIO, "error setting audio format");
    return false;
  }

  callback_struct.inputProc = callback;
  callback_struct.inputProcRefCon = this;
  err = AudioUnitSetProperty(audio_unit, kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input, 0, &callback_struct, sizeof callback_struct);
  if (err != noErr)
  {
    ERROR_LOG_FMT(AUDIO, "error setting audio callback");
    return false;
  }

  err = AudioUnitSetParameter(audio_unit, kHALOutputParam_Volume, kAudioUnitScope_Output, 0,
                              m_volume / 100., 0);
  if (err != noErr)
    ERROR_LOG_FMT(AUDIO, "error setting volume");

  err = AudioUnitInitialize(audio_unit);
  if (err != noErr)
  {
    ERROR_LOG_FMT(AUDIO, "error initializing audiounit");
    return false;
  }

  AudioStreamBasicDescription actual_format{};
  UInt32 actual_size = sizeof(actual_format);
  if (AudioUnitGetProperty(audio_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                           &actual_format, &actual_size) == noErr &&
      actual_format.mSampleRate > 0.0)
  {
    const u32 actual_rate = static_cast<u32>(std::lround(actual_format.mSampleRate));
    if (actual_rate != m_mixer->GetSampleRate())
      m_mixer->SetSampleRate(actual_rate);
    m_actual_channels = (actual_format.mChannelsPerFrame > 0) ? actual_format.mChannelsPerFrame : 2;
  }

  return true;
}

bool CoreAudioSound::SetRunning(bool running)
{
  OSStatus err;
  if (running)
  {
    err = AudioOutputUnitStart(audio_unit);
    if (err != noErr)
    {
      ERROR_LOG_FMT(AUDIO, "error starting audiounit");
      return false;
    }
  }
  else
  {
    err = AudioOutputUnitStop(audio_unit);
    if (err != noErr)
      ERROR_LOG_FMT(AUDIO, "error stopping audiounit");
  }
  return true;
}

void CoreAudioSound::SetVolume(int volume)
{
  OSStatus err;
  m_volume = volume;

  err = AudioUnitSetParameter(audio_unit, kHALOutputParam_Volume, kAudioUnitScope_Output, 0,
                              volume / 100., 0);
  if (err != noErr)
    ERROR_LOG_FMT(AUDIO, "error setting volume");
}
