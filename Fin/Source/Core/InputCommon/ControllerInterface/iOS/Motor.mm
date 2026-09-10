// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#include <CoreHaptics/CoreHaptics.h>
#include <Foundation/Foundation.h>

#include "Common/Logging/Log.h"

#include "InputCommon/ControllerInterface/ControllerInterface.h"
#include "InputCommon/ControllerInterface/iOS/Motor.h"

#define MOTOR_ERROR_LOG(x, y) ERROR_LOG_FMT(CONTROLLERINTERFACE, x, [[y localizedDescription] UTF8String])

// #region agent log
static void AgentDebugLog(NSString* location, NSString* message, NSDictionary* data, NSString* hypothesisId) {
  NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"debug.log"];
  NSDictionary* payload = @{
    @"sessionId": @"debug-session",
    @"runId": @"run1",
    @"hypothesisId": hypothesisId ?: @"",
    @"location": location ?: @"",
    @"message": message ?: @"",
    @"data": data ?: @{},
    @"timestamp": @(([[NSDate date] timeIntervalSince1970] * 1000))
  };
  NSError* err;
  NSData* json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&err];
  if (json) {
    NSMutableData* line = [json mutableCopy];
    [line appendBytes:"\n" length:1];
    NSFileHandle* f = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!f) [[NSData data] writeToFile:path atomically:NO];
    f = [NSFileHandle fileHandleForUpdatingAtPath:path];
    if (f) { [f seekToEndOfFile]; [f writeData:line]; [f closeFile]; }
  }
}
// #endregion

namespace ciface::iOS
{
Motor::Motor(CHHapticEngine* engine, const std::string name) : m_haptic_engine(engine), m_name(std::move(name))
{
  // #region agent log
  AgentDebugLog(@"Motor.mm:Motor()", @"Motor constructor entry", @{ @"onMainThread": @([NSThread isMainThread]) }, @"H1");
  // #endregion
  std::lock_guard<std::mutex> guard(m_lock);

  if ([NSThread isMainThread])
  {
    if (!StartEngine())
      return;
  }
  else
  {
    // Core Haptics XPC helper often fails with "Couldn't communicate with a helper application"
    // when createAdvancedPlayerWithPattern is called off the main thread or too early. Defer to main.
    __weak CHHapticEngine* weakEngine = m_haptic_engine;
    dispatch_async(dispatch_get_main_queue(), ^{
      __strong CHHapticEngine* strongEngine = weakEngine;
      if (!strongEngine) return;
      std::lock_guard<std::mutex> inner_guard(m_lock);
      if (m_engine_destroyed) return;
      StartEngine();
    });
  }

  m_haptic_engine.resetHandler = ^{
    std::lock_guard<std::mutex> reset_guard(m_lock);

    m_player_created = false;

    m_haptic_player = nil;

    StartEngine();
  };

  m_haptic_engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
    std::lock_guard<std::mutex> stopped_guard(m_lock);

    switch (reason)
    {
    case CHHapticEngineStoppedReasonAudioSessionInterrupt:
    case CHHapticEngineStoppedReasonApplicationSuspended:
    case CHHapticEngineStoppedReasonSystemError:
      m_player_needs_restart = true;

      break;
    case 4:  // CHHapticEngineStoppedReasonGameControllerDisconnect
      m_player_needs_restart = true;
      break;
    case 5:  // CHHapticEngineStoppedReasonEngineDestroyed - e.g. opening controller settings, app background
      m_player_created = false;
      m_engine_destroyed = true;  // Do not call stop in destructor; XPC helper may be gone
      break;
    default:
      ERROR_LOG_FMT(CONTROLLERINTERFACE, "Motor received unexpected stopped reason: {}", (NSInteger)reason);

      m_player_created = false;

      break;
    }
  };
}

Motor::~Motor()
{
  std::lock_guard<std::mutex> guard(m_lock);

  if (m_engine_destroyed)
  {
    return;
  }
  if (m_player_created)
  {
    [m_haptic_engine stopWithCompletionHandler:nil];
  }
}

bool Motor::StartEngine()
{
  // #region agent log
  AgentDebugLog(@"Motor.mm:StartEngine()", @"StartEngine entry", @{ @"onMainThread": @([NSThread isMainThread]) }, @"H1");
  // #endregion
  NSError* error;

  if (![m_haptic_engine startAndReturnError:&error])
  {
    // #region agent log
    AgentDebugLog(@"Motor.mm:StartEngine()", @"startAndReturnError failed", @{ @"error": error ? [error localizedDescription] : @"nil", @"onMainThread": @([NSThread isMainThread]) }, @"H4");
    // #endregion
    MOTOR_ERROR_LOG("Motor failed to start CHHapticEngine: {}", error);

    return false;
  }

  // Continuous rumble: intensity (amplitude) and sharpness (frequency character) per Core Haptics.
  CHHapticEventParameter* intensity_param = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0f];
  CHHapticEventParameter* sharpness_param = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.5f];

  CHHapticEvent* event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                       parameters:@[intensity_param, sharpness_param]
                                                     relativeTime:0.0f
                                                         duration:1.0f];

  CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];

  if (error != nil)
  {
    MOTOR_ERROR_LOG("Motor failed to create CHHapticPattern: {}", error);

    return false;
  }

  m_haptic_player = [m_haptic_engine createAdvancedPlayerWithPattern:pattern error:&error];

  if (error != nil)
  {
    // #region agent log
    AgentDebugLog(@"Motor.mm:StartEngine()", @"createAdvancedPlayerWithPattern failed", @{ @"error": [error localizedDescription], @"onMainThread": @([NSThread isMainThread]) }, @"H1");
    // #endregion
    MOTOR_ERROR_LOG("Motor failed to create CHHapticAdvancedPatternPlayer: {}", error);

    return false;
  }

  [m_haptic_player setLoopEnabled:true];
  [m_haptic_player setLoopEnd:0.0f];

  m_player_created = true;
  m_player_needs_restart = false;

  return true;
}

std::string Motor::GetName() const
{
  return m_name;
}

void Motor::SetState(ControlState state)
{
  std::lock_guard<std::mutex> guard(m_lock);

  if (!m_player_created || state == m_last_state)
  {
    return;
  }

  if (m_player_needs_restart)
  {
    if (!StartEngine())
    {
      return;
    }
  }

  bool result;
  NSError* error;

  if (state > 0)
  {
    result = [m_haptic_player startAtTime:CHHapticTimeImmediate error:&error];
  }
  else
  {
    result = [m_haptic_player stopAtTime:CHHapticTimeImmediate error:&error];
  }

  if (!result)
  {
    MOTOR_ERROR_LOG("Motor failed to start/stop haptics: {}", error);
  }

  m_last_state = state;
}
}  // namespace ciface::iOS
