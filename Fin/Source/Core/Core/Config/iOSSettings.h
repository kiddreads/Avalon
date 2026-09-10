// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "Common/Config/Config.h"

namespace Config
{
// Main.iOS

extern const Info<float> MAIN_TOUCH_PAD_OPACITY;
extern const Info<int> MAIN_TOUCH_PAD_IR_MODE;
extern const Info<int> MAIN_SELECTED_STATE_SLOT;
extern const Info<int> MAIN_MUTE_SWITCH_MODE;
extern const Info<bool> MAIN_PAUSE_WHEN_IN_MENU;
extern const Info<bool> MAIN_REWIND_ENABLED;

// Bell Audio (Experimental) - iOS audio improvements
extern const Info<bool> MAIN_BELL_AUDIO_ENABLED;
extern const Info<bool> MAIN_BELL_AUDIO_ADAPTIVE_BUFFERING;
extern const Info<bool> MAIN_BELL_AUDIO_NEON_MIXING;
extern const Info<bool> MAIN_BELL_AUDIO_DRIVEN_PACING;
extern const Info<bool> MAIN_BELL_AUDIO_UNDERRUN_PROTECTION;
extern const Info<bool> MAIN_BELL_AUDIO_DYNAMIC_RATE_CORRECTION;
extern const Info<bool> MAIN_BELL_AUDIO_HQ_PROCESSING;

}  // namespace Config
