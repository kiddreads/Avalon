// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "VideoCommon/Slang/SlangCompiler.h"

#include "Common/Logging/Log.h"
#include "VideoCommon/Spirv.h"
#include "VideoCommon/VideoCommon.h"

namespace Slang
{
bool Compiler::CompilePass(const PassSource& source, CompiledPass* out_pass,
                           std::vector<std::string>* errors)
{
  if (!out_pass)
    return false;

  auto vs = SPIRV::CompileVertexShader(source.vertex_source, APIType::Metal,
                                       glslang::EShTargetSpv_1_5);
  if (!vs.has_value())
  {
    if (errors)
      errors->push_back("Failed to compile Slang vertex shader");
    return false;
  }

  auto ps = SPIRV::CompileFragmentShader(source.fragment_source, APIType::Metal,
                                         glslang::EShTargetSpv_1_5);
  if (!ps.has_value())
  {
    if (errors)
      errors->push_back("Failed to compile Slang fragment shader");
    return false;
  }

  out_pass->vertex_spirv = *vs;
  out_pass->fragment_spirv = *ps;
  return true;
}
}  // namespace Slang
