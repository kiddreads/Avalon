// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <optional>
#include <string>
#include <vector>

#include "Common/CommonTypes.h"
#include "VideoCommon/Slang/SlangParser.h"

namespace Slang
{
struct CompiledPass
{
  std::vector<u32> vertex_spirv;
  std::vector<u32> fragment_spirv;
};

class Compiler
{
public:
  static bool CompilePass(const PassSource& source, CompiledPass* out_pass,
                          std::vector<std::string>* errors);
};
}  // namespace Slang
