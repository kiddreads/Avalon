// Copyright 2025 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <cstddef>
#include <cstdint>

// Optional native video decode on iOS using VideoToolbox (hardware MPEG-2).
// When enabled, DVD read data is fed here; decoded frames can be composited
// over the game output to smooth FMV during cutscenes.
// Only built and used on iOS (#ifdef IPHONEOS).

#ifdef IPHONEOS

// Register with DVDThread and start receiving read data. Call once at init.
void NativeVideoDecoder_Init();

// Unregister and release resources.
void NativeVideoDecoder_Shutdown();

// Called by DVDThread when a read completes (set automatically by Init).
void NativeVideoDecoder_OnDVDReadComplete(uint64_t dvd_offset, uint32_t length,
                                         const uint8_t* data, size_t size);

// Returns the latest decoded frame as a CVPixelBufferRef, or nullptr.
// Caller must CFRelease the returned value if non-null when done.
void* NativeVideoDecoder_GetCurrentFrame();

// Whether native decode is enabled (e.g. from config).
bool NativeVideoDecoder_IsEnabled();

#else

inline void NativeVideoDecoder_Init() {}
inline void NativeVideoDecoder_Shutdown() {}
inline void NativeVideoDecoder_OnDVDReadComplete(uint64_t, uint32_t, const uint8_t*, size_t) {}
inline void* NativeVideoDecoder_GetCurrentFrame() { return nullptr; }
inline bool NativeVideoDecoder_IsEnabled() { return false; }

#endif
