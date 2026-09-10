// Copyright 2025 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "AudioSessionManager.h"

#import <AVFoundation/AVFoundation.h>

#import "Core/Config/MainSettings.h"
#import "Core/Config/iOSSettings.h"
#import <string>

#import "Swift.h"

// Preferred IO buffer duration for emulation (seconds). Larger buffer reduces underruns and
// choppy audio when the CPU is busy during DVD reads and video/cutscenes (e.g. FMV).
static const NSTimeInterval kEmulationPreferredIOBufferDuration = 0.100;

// Bell Audio: Adaptive buffering - smaller buffer when stable, larger when under stress
static const NSTimeInterval kBellAudioLowLatencyBufferDuration = 0.005;  // ~128-256 frames at 48kHz
static const NSTimeInterval kBellAudioStableBufferDuration = 0.010;       // ~512 frames at 48kHz
static const NSTimeInterval kBellAudioStressedBufferDuration = 0.020;    // ~1024 frames at 48kHz

@implementation AudioSessionManager {
  BOOL _observingRouteChanges;
}

+ (AudioSessionManager*)shared {
  static AudioSessionManager* sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });

  return sharedInstance;
}

- (void)dealloc {
  if (_observingRouteChanges) {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionRouteChangeNotification
                                                  object:nil];
  }
}

- (void)setSessionCategory {
  AVAudioSession* session = [AVAudioSession sharedInstance];
  AudioMuteSwitchMode mode = (AudioMuteSwitchMode)Config::Get(Config::MAIN_MUTE_SWITCH_MODE);
  if (mode == AudioMuteSwitchModeObey) {
    [session setCategory:AVAudioSessionCategorySoloAmbient error:nil];
  } else {
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
  }
}

- (void)prepareForEmulationPlayback {
  AVAudioSession* session = [AVAudioSession sharedInstance];

  [self setSessionCategory];

  BOOL upsampling = Config::Get(Config::MAIN_AUDIO_UPSAMPLING);
  [session setPreferredSampleRate:(upsampling ? 96000.0 : 48000.0) error:nil];

  // Channel count: 0=Mono(1), 1=Stereo(2), 2=Surround(6).
  int outputMode = Config::Get(Config::MAIN_AUDIO_OUTPUT_MODE);
  int channels = (outputMode == 2) ? 6 : (outputMode == 0) ? 1 : 2;
  [session setPreferredOutputNumberOfChannels:channels error:nil];

  // Buffer duration: use adaptive buffering if Bell backend is selected, otherwise use fixed larger buffer
  std::string backend = Config::Get(Config::MAIN_AUDIO_BACKEND);
  BOOL isBellBackend = (backend == "Bell");
  BOOL adaptiveBuffering = Config::Get(Config::MAIN_BELL_AUDIO_ADAPTIVE_BUFFERING);
  
  NSTimeInterval bufferDuration;
  if (isBellBackend && adaptiveBuffering) {
    // Pick buffer based on current output route (headphones = tighter, speaker = larger)
    bufferDuration = [self bellBufferDurationForCurrentRoute];
  } else {
    // Default: larger buffer for headroom during CPU hitches
    bufferDuration = kEmulationPreferredIOBufferDuration;
  }
  [session setPreferredIOBufferDuration:bufferDuration error:nil];

  // Register for route changes so we can adapt buffer size on the fly (e.g. headphones plugged/unplugged)
  if (isBellBackend && adaptiveBuffering && !_observingRouteChanges) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    _observingRouteChanges = YES;
  }

  [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)endEmulationPlayback {
  AVAudioSession* session = [AVAudioSession sharedInstance];

  [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];

  // Reset to default buffer so other apps (music, etc.) aren't stuck with our larger buffer.
  [session setPreferredIOBufferDuration:0.005 error:nil];

  // Stop observing route changes
  if (_observingRouteChanges) {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionRouteChangeNotification
                                                  object:nil];
    _observingRouteChanges = NO;
  }
}

- (void)updateBufferDuration:(NSTimeInterval)duration {
  AVAudioSession* session = [AVAudioSession sharedInstance];
  [session setPreferredIOBufferDuration:duration error:nil];
}

// Bell Audio: Pick optimal buffer duration based on current audio output route
// Wired headphones / Lightning DAC = low latency; Bluetooth = stable; Speaker = stressed (larger)
- (NSTimeInterval)bellBufferDurationForCurrentRoute {
  AVAudioSession* session = [AVAudioSession sharedInstance];
  AVAudioSessionRouteDescription* route = [session currentRoute];
  
  for (AVAudioSessionPortDescription* output in route.outputs) {
    NSString* portType = output.portType;
    
    // Wired headphones or Lightning/USB DAC: lowest latency
    if ([portType isEqualToString:AVAudioSessionPortHeadphones] ||
        [portType isEqualToString:AVAudioSessionPortUSBAudio]) {
      return kBellAudioLowLatencyBufferDuration;
    }
    
    // Bluetooth: use stable buffer (BT has its own buffering layer)
    if ([portType isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
        [portType isEqualToString:AVAudioSessionPortBluetoothHFP] ||
        [portType isEqualToString:AVAudioSessionPortBluetoothLE]) {
      return kBellAudioStressedBufferDuration;
    }
  }
  
  // Built-in speaker or unknown: use stable buffer
  return kBellAudioStableBufferDuration;
}

// Bell Audio: Handle audio route changes (headphones plugged/unplugged, BT connected, etc.)
- (void)handleRouteChange:(NSNotification*)notification {
  std::string backend = Config::Get(Config::MAIN_AUDIO_BACKEND);
  BOOL isBellBackend = (backend == "Bell");
  BOOL adaptiveBuffering = Config::Get(Config::MAIN_BELL_AUDIO_ADAPTIVE_BUFFERING);
  
  if (isBellBackend && adaptiveBuffering) {
    NSTimeInterval newDuration = [self bellBufferDurationForCurrentRoute];
    [self updateBufferDuration:newDuration];
  }
}

@end
