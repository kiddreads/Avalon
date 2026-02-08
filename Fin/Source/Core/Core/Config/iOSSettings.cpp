// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "Core/Config/iOSSettings.h"

namespace Config
{
// Main.iOS

const Info<float> MAIN_TOUCH_PAD_OPACITY{{System::Main, "iOS", "TouchPadOpacity"}, 0.50f};
const Info<int> MAIN_TOUCH_PAD_IR_MODE{{System::Main, "iOS", "TouchPadIRMode"}, 2};
const Info<int> MAIN_SELECTED_STATE_SLOT{{System::Main, "iOS", "SelectedStateSlot"}, 1};
const Info<int> MAIN_MUTE_SWITCH_MODE{{System::Main, "iOS", "MuteSwitchMode"}, 0};
const Info<bool> MAIN_PAUSE_WHEN_IN_MENU{{System::Main, "iOS", "PauseWhenInMenu"}, true};
const Info<bool> MAIN_REWIND_ENABLED{{System::Main, "iOS", "RewindEnabled"}, false};

// Bell Audio - iOS audio improvements (enabled when Bell backend is selected)
// Defaults to false - only enabled when Bell backend is explicitly chosen
const Info<bool> MAIN_BELL_AUDIO_ENABLED{{System::Main, "iOS", "BellAudioEnabled"}, false};
const Info<bool> MAIN_BELL_AUDIO_ADAPTIVE_BUFFERING{{System::Main, "iOS", "BellAudioAdaptiveBuffering"}, false};
const Info<bool> MAIN_BELL_AUDIO_NEON_MIXING{{System::Main, "iOS", "BellAudioNEONMixing"}, false};
const Info<bool> MAIN_BELL_AUDIO_DRIVEN_PACING{{System::Main, "iOS", "BellAudioDrivenPacing"}, false};
const Info<bool> MAIN_BELL_AUDIO_UNDERRUN_PROTECTION{{System::Main, "iOS", "BellAudioUnderrunProtection"}, false};
const Info<bool> MAIN_BELL_AUDIO_DYNAMIC_RATE_CORRECTION{{System::Main, "iOS", "BellAudioDynamicRateCorrection"}, false};
const Info<bool> MAIN_BELL_AUDIO_HQ_PROCESSING{{System::Main, "iOS", "BellAudioHQProcessing"}, false};

}  // namespace Config
