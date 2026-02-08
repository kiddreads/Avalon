// Copyright 2025 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#ifdef IPHONEOS

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

#include "Core/HW/DVD/DVDThread.h"
#include "Core/HW/DVD/NativeVideoDecoder.h"

#include "Core/Config/GraphicsSettings.h"
#include "Common/Config/Config.h"

#include <algorithm>
#include <mutex>
#include <vector>

namespace
{
constexpr size_t kMaxBufferSize = 1024 * 1024;  // 1 MB
constexpr size_t kMinChunkSize = 32 * 1024;    // Try decode when we have 32 KB

std::mutex g_decoder_mutex;
std::mutex g_frame_mutex;  // Only for g_current_frame (callback + GetCurrentFrame)
std::vector<uint8_t> g_read_buffer;
VTDecompressionSessionRef g_session = nullptr;
CVPixelBufferRef g_current_frame = nullptr;  // retained
bool g_enabled = false;

// MPEG-2 start code: 0x00 0x00 0x01
static bool FindStartCode(const uint8_t* data, size_t size, size_t* out_offset)
{
  for (size_t i = 0; i + 3 <= size; ++i)
  {
    if (data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1)
    {
      *out_offset = i;
      return true;
    }
  }
  return false;
}

// Find next start code after 'start', return length to it (or to end of buffer).
static size_t LengthToNextStartCode(const uint8_t* data, size_t start, size_t size)
{
  for (size_t i = start + 3; i + 3 <= size; ++i)
  {
    if (data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1)
      return i - start;
  }
  return size - start;
}

void DecoderOutputCallback(void* decompression_output_ref_con, void* source_frame_ref_con,
                          OSStatus status, VTDecodeInfoFlags info_flags, CVImageBufferRef image_buffer,
                          CMTime presentation_time_stamp, CMTime presentation_duration)
{
  if (status != noErr || !image_buffer)
    return;
  std::lock_guard lock(g_frame_mutex);
  if (g_current_frame)
    CVPixelBufferRelease(g_current_frame);
  g_current_frame = CVPixelBufferRetain((CVPixelBufferRef)image_buffer);
}

bool TryDecodeChunk(const uint8_t* data, size_t size)
{
  if (!g_session || size < 4)
    return false;

  size_t start = 0;
  if (!FindStartCode(data, size, &start))
    return false;  // No start code, discard
  size_t chunk_len = LengthToNextStartCode(data, start, size);
  if (chunk_len < 4)
    return false;

  // Use sync decode so VT doesn't hold the buffer after we return (caller may erase).
  OSStatus err;
  CMBlockBufferRef block_buf = nullptr;
  err = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, (void*)(data + start), chunk_len,
                                          kCFAllocatorNull, nullptr, 0, chunk_len, 0, &block_buf);
  if (err != noErr)
    return false;

  CMSampleBufferRef sample_buf = nullptr;
  CMSampleTimingInfo timing = {};
  timing.duration = CMTimeMake(1, 30);
  timing.presentationTimeStamp = CMTimeMake(0, 30);
  timing.decodeTimeStamp = kCMTimeInvalid;
  err = CMSampleBufferCreate(kCFAllocatorDefault, block_buf, true, nullptr, nullptr, nullptr, 1, 1,
                             &timing, 0, nullptr, &sample_buf);
  CFRelease(block_buf);
  if (err != noErr)
    return false;

  VTDecodeFrameFlags flags = 0;  // Synchronous so callback runs before DecodeFrame returns
  err = VTDecompressionSessionDecodeFrame(g_session, sample_buf, flags, nullptr, nullptr);
  CFRelease(sample_buf);
  if (err != noErr)
  {
    // If the hardware decoder starts erroring (e.g. VTDecompressionSessionHandleAnyFormatDescriptionChange
    // with kVTFormatDescriptionChangeNotSupportedErr / NULL format description),
    // tear down the session and permanently disable native video decode for this run.
    // This prevents continuous VT-DS spam and avoids repeatedly feeding a bad session.
    VTDecompressionSessionInvalidate(g_session);
    CFRelease(g_session);
    g_session = nullptr;
    g_enabled = false;
    return false;
  }

  return true;
}

void EnsureSession()
{
  if (g_session)
    return;
  CMVideoFormatDescriptionRef fmt = nullptr;
  // Minimal MPEG-2 format: 720x480, generic
  OSStatus err = CMVideoFormatDescriptionCreate(
      kCFAllocatorDefault, kCMVideoCodecType_MPEG2Video, 720, 480, nullptr, &fmt);
  if (err != noErr)
    return;
  NSDictionary* dest_attrs = @{
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
  };
  VTDecompressionOutputCallbackRecord cb = {DecoderOutputCallback, nullptr};
  err = VTDecompressionSessionCreate(kCFAllocatorDefault, fmt, nullptr,
                                     (__bridge CFDictionaryRef)dest_attrs, &cb, &g_session);
  CFRelease(fmt);
  if (err != noErr)
    g_session = nullptr;
}
}  // namespace

void NativeVideoDecoder_Init()
{
  std::lock_guard lock(g_decoder_mutex);
  g_enabled = true;
  g_read_buffer.reserve(kMaxBufferSize);
  DVD::DVDThread::g_on_dvd_read_complete = NativeVideoDecoder_OnDVDReadComplete;
}

void NativeVideoDecoder_Shutdown()
{
  std::lock_guard lock(g_decoder_mutex);
  DVD::DVDThread::g_on_dvd_read_complete = nullptr;
  g_enabled = false;
  g_read_buffer.clear();
  if (g_session)
  {
    VTDecompressionSessionInvalidate(g_session);
    CFRelease(g_session);
    g_session = nullptr;
  }
  if (g_current_frame)
  {
    CVPixelBufferRelease(g_current_frame);
    g_current_frame = nullptr;
  }
}

void NativeVideoDecoder_OnDVDReadComplete(uint64_t dvd_offset, uint32_t length,
                                         const uint8_t* data, size_t size)
{
  if (!g_enabled || !Config::Get(Config::GFX_USE_NATIVE_VIDEO_DECODE) || !data || size == 0)
    return;
  std::lock_guard lock(g_decoder_mutex);
  size_t to_append = std::min(size, kMaxBufferSize - g_read_buffer.size());
  if (to_append == 0)
    g_read_buffer.erase(g_read_buffer.begin(),
                        g_read_buffer.begin() + (size / 2));  // Discard old half
  to_append = std::min(size, kMaxBufferSize - g_read_buffer.size());
  g_read_buffer.insert(g_read_buffer.end(), data, data + to_append);

  while (g_read_buffer.size() >= kMinChunkSize)
  {
    EnsureSession();
    if (!g_session)
      break;
    bool decoded = TryDecodeChunk(g_read_buffer.data(), g_read_buffer.size());
    size_t start = 0;
    if (FindStartCode(g_read_buffer.data(), g_read_buffer.size(), &start))
    {
      size_t consumed = LengthToNextStartCode(g_read_buffer.data(), start, g_read_buffer.size());
      g_read_buffer.erase(g_read_buffer.begin(), g_read_buffer.begin() + start + consumed);
    }
    else
    {
      g_read_buffer.clear();
      break;
    }
    if (!decoded)
      break;  // Avoid spinning
  }
}

void* NativeVideoDecoder_GetCurrentFrame()
{
  std::lock_guard lock(g_frame_mutex);
  if (g_current_frame)
    CVPixelBufferRetain(g_current_frame);
  return g_current_frame;
}

bool NativeVideoDecoder_IsEnabled()
{
  return g_enabled && Config::Get(Config::GFX_USE_NATIVE_VIDEO_DECODE);
}

#endif  // IPHONEOS
