// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <string>
#include <string_view>
#include <vector>

#include "VideoCommon/Slang/SlangParser.h"

namespace Slang
{
// Parse an mpv/Anime4K-style multi-pass .glsl file (using //!HOOK, //!BIND, //!SAVE, etc.)
// into a vector of Slang::Pass objects that can be fed to the Slang runtime pipeline.
// Returns false if the code does not look like a valid mpv multi-pass shader or on parse error.
bool ParseMpvGlsl(std::string_view code, std::vector<Pass>* out_passes,
                  std::vector<std::string>* errors = nullptr);
}  // namespace Slang
