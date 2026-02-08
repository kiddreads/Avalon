// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "VideoCommon/Slang/SlangRuntime.h"

#include <cstring>

#include "Common/Logging/Log.h"
#include "Common/Timer.h"
#include "VideoCommon/AbstractFramebuffer.h"
#include "VideoCommon/AbstractGfx.h"
#include "VideoCommon/AbstractPipeline.h"
#include "VideoCommon/AbstractShader.h"
#include "VideoCommon/AbstractTexture.h"
#include "VideoCommon/RenderState.h"
#include "VideoCommon/VideoConfig.h"
#include "VideoCommon/VertexManagerBase.h"

namespace Slang
{
namespace
{
AbstractTextureFormat MapFormat(const std::string& fmt)
{
  if (fmt == "R8G8B8A8_UNORM" || fmt == "RGBA8")
    return AbstractTextureFormat::RGBA8;
  if (fmt == "R16G16B16A16_SFLOAT" || fmt == "RGBA16F")
    return AbstractTextureFormat::RGBA16F;
  return AbstractTextureFormat::RGBA16F;
}

struct alignas(16) SlangUniforms
{
  float mvp[16];
  float source_size[4];
  float output_size[4];
  float final_viewport_size[4];
  u32 frame_count;
  s32 frame_direction;
  float exposure;
  float hdr_output;
  float pad[2];
};
}  // namespace

bool Runtime::LoadPreset(const std::string& path, std::vector<std::string>* errors)
{
  Preset preset;
  if (!Parser::LoadPreset(path, &preset, errors))
    return false;

  if (!BuildPipelines(preset.passes, errors))
    return false;

  // Default RT format: first pass format or RGBA16F
  if (!preset.passes.empty() && !preset.passes[0].source.format.empty())
    m_rt_format = MapFormat(preset.passes[0].source.format);

  return true;
}

bool Runtime::LoadPasses(const std::vector<Pass>& passes, std::vector<std::string>* errors)
{
  if (!BuildPipelines(passes, errors))
    return false;

  // Default RT format: first pass format or RGBA16F
  if (!passes.empty() && !passes[0].source.format.empty())
    m_rt_format = MapFormat(passes[0].source.format);

  return true;
}

bool Runtime::BuildPipelines(const std::vector<Pass>& passes, std::vector<std::string>* errors)
{
  m_passes.clear();
  m_passes.reserve(passes.size());

  for (const auto& p : passes)
  {
    PassRuntime pr;
    pr.pass = p;

    if (!Compiler::CompilePass(p.source, &pr.compiled, errors))
      return false;

    auto vs_msl = g_gfx->TranslateSlangSPIRVToMSL(ShaderStage::Vertex, pr.compiled.vertex_spirv);
    auto ps_msl = g_gfx->TranslateSlangSPIRVToMSL(ShaderStage::Pixel, pr.compiled.fragment_spirv);
    if (!vs_msl.has_value() || !ps_msl.has_value())
    {
      if (errors)
        errors->push_back("Failed SPIR-V -> MSL for pass: " + p.path);
      return false;
    }

    pr.vs = g_gfx->CreateShaderFromBinary(ShaderStage::Vertex, vs_msl->data(), vs_msl->size(),
                                          "Slang VS");
    pr.ps = g_gfx->CreateShaderFromBinary(ShaderStage::Pixel, ps_msl->data(), ps_msl->size(),
                                          "Slang PS");
    if (!pr.vs || !pr.ps)
    {
      if (errors)
        errors->push_back("Failed to create shaders for pass: " + p.path);
      return false;
    }

    AbstractPipelineConfig cfg = {};
    cfg.vertex_shader = pr.vs.get();
    cfg.geometry_shader = nullptr;
    cfg.pixel_shader = pr.ps.get();
    cfg.rasterization_state = RenderState::GetNoCullRasterizationState(PrimitiveType::Triangles);
    cfg.depth_state = RenderState::GetNoDepthTestingDepthState();
    cfg.blending_state = RenderState::GetNoBlendingBlendState();
    cfg.framebuffer_state = RenderState::GetColorFramebufferState(MapFormat(p.source.format));
    cfg.usage = AbstractPipelineUsage::Utility;
    pr.pipeline = g_gfx->CreatePipeline(cfg);
    if (!pr.pipeline)
    {
      if (errors)
        errors->push_back("Failed to create pipeline for pass: " + p.path);
      return false;
    }

    m_passes.push_back(std::move(pr));
  }

  return true;
}

bool Runtime::EnsureRenderTargets(u32 width, u32 height, u32 samples)
{
  for (size_t i = 0; i + 1 < m_passes.size(); ++i)
  {
    auto& pr = m_passes[i];
    if (pr.rt_texture && pr.rt_texture->GetWidth() == width && pr.rt_texture->GetHeight() == height)
      continue;

    const TextureConfig cfg(width, height, 1, 1, samples, m_rt_format,
                            AbstractTextureFlag_RenderTarget, AbstractTextureType::Texture_2DArray);
    pr.rt_texture = g_gfx->CreateTexture(cfg, "Slang pass RT");
    pr.rt_fbo = g_gfx->CreateFramebuffer(pr.rt_texture.get(), nullptr);
    if (!pr.rt_texture || !pr.rt_fbo)
      return false;
  }
  return true;
}

bool Runtime::Blit(const MathUtil::Rectangle<int>& dst, const MathUtil::Rectangle<int>& src,
                   const AbstractTexture* src_tex)
{
  if (m_passes.empty())
    return false;

  const u32 width = static_cast<u32>(dst.GetWidth());
  const u32 height = static_cast<u32>(dst.GetHeight());
  const u32 samples = src_tex->GetSamples();
  if (!EnsureRenderTargets(width, height, samples))
    return false;

  // Track current source texture for chaining
  const AbstractTexture* current_src = src_tex;

  for (size_t i = 0; i < m_passes.size(); ++i)
  {
    auto& pr = m_passes[i];
    const bool last = (i + 1 == m_passes.size());

    AbstractFramebuffer* target_fbo =
        last ? g_gfx->GetCurrentFramebuffer() : pr.rt_fbo.get();

    g_gfx->SetFramebuffer(target_fbo);
    g_gfx->SetTexture(0, current_src);
    g_gfx->SetSamplerState(0, RenderState::GetLinearSamplerState());

    SlangUniforms ubo = {};
    // MVP = identity
    ubo.mvp[0] = ubo.mvp[5] = ubo.mvp[10] = ubo.mvp[15] = 1.0f;
    ubo.source_size[0] = static_cast<float>(current_src->GetWidth());
    ubo.source_size[1] = static_cast<float>(current_src->GetHeight());
    ubo.source_size[2] = 1.0f / ubo.source_size[0];
    ubo.source_size[3] = 1.0f / ubo.source_size[1];
    ubo.output_size[0] = static_cast<float>(dst.GetWidth());
    ubo.output_size[1] = static_cast<float>(dst.GetHeight());
    ubo.output_size[2] = 1.0f / ubo.output_size[0];
    ubo.output_size[3] = 1.0f / ubo.output_size[1];
    ubo.final_viewport_size[0] = ubo.output_size[0];
    ubo.final_viewport_size[1] = ubo.output_size[1];
    ubo.final_viewport_size[2] = ubo.output_size[2];
    ubo.final_viewport_size[3] = ubo.output_size[3];
    ubo.frame_count = static_cast<u32>(Common::Timer::NowMs());
    ubo.frame_direction = 1;
    ubo.exposure = g_ActiveConfig.color_correction.fExposure;
    ubo.hdr_output = (m_rt_format == AbstractTextureFormat::RGBA16F) ? 1.0f : 0.0f;

    g_vertex_manager->UploadUtilityUniforms(&ubo, sizeof(ubo));
    g_gfx->SetViewportAndScissor(dst);
    g_gfx->SetPipeline(pr.pipeline.get());
    g_gfx->Draw(0, 3);

    if (!last)
      current_src = pr.rt_texture.get();
  }

  return true;
}
}  // namespace Slang
