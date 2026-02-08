// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <memory>
#include <string>
#include <vector>

#include "Common/MathUtil.h"
#include "VideoCommon/TextureConfig.h"
#include "VideoCommon/Slang/SlangCompiler.h"
#include "VideoCommon/Slang/SlangParser.h"

class AbstractFramebuffer;
class AbstractPipeline;
class AbstractShader;
class AbstractTexture;

namespace Slang
{
class Runtime
{
public:
  bool LoadPreset(const std::string& path, std::vector<std::string>* errors = nullptr);

  // Load from pre-parsed passes (e.g. from mpv/Anime4K GLSL conversion).
  bool LoadPasses(const std::vector<Pass>& passes, std::vector<std::string>* errors = nullptr);

  // Execute the slang chain. Returns false on failure; on failure, caller should fall back to GLSL.
  bool Blit(const MathUtil::Rectangle<int>& dst, const MathUtil::Rectangle<int>& src,
            const AbstractTexture* src_tex);

private:
  struct PassRuntime
  {
    Pass pass;
    CompiledPass compiled;
    std::unique_ptr<AbstractShader> vs;
    std::unique_ptr<AbstractShader> ps;
    std::unique_ptr<AbstractPipeline> pipeline;
    std::unique_ptr<AbstractTexture> rt_texture;
    std::unique_ptr<AbstractFramebuffer> rt_fbo;
  };

  bool BuildPipelines(const std::vector<Pass>& passes, std::vector<std::string>* errors);
  bool EnsureRenderTargets(u32 width, u32 height, u32 samples);

  std::vector<PassRuntime> m_passes;
  AbstractTextureFormat m_rt_format = AbstractTextureFormat::RGBA16F;
};
}  // namespace Slang
