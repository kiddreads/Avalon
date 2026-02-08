// Copyright 2025 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioSessionManager : NSObject

+ (AudioSessionManager*)shared;

- (void)setSessionCategory;

/// Call before starting emulation: sets playback category, preferred buffer duration, and activates the session for lower latency and fewer underruns.
- (void)prepareForEmulationPlayback;

/// Call when emulation ends: deactivates the session and resets preferred buffer so other apps aren't affected.
- (void)endEmulationPlayback;

/// Update buffer duration dynamically (for adaptive buffering). Called during emulation if needed.
- (void)updateBufferDuration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
