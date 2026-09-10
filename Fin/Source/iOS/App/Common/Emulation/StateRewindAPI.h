// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

// Thin declarations for State APIs used by EmulationCoordinator slot-based
// save/load. Avoids pulling in Core/State.h (and Common/Buffer.h).

#pragma once

#include <cstddef>

#include "Common/CommonTypes.h"

namespace Core
{
class System;
}

namespace State
{
void Save(Core::System& system, int slot, bool wait = false);
void Load(Core::System& system, int slot);

size_t GetSaveStateSize(Core::System& system);
void SaveToBuffer(Core::System& system, u8* buffer, size_t buffer_size);
void LoadFromBuffer(Core::System& system, const u8* buffer, size_t buffer_size);
}
