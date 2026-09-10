// Copyright 2022 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "VideoBackends/Metal/MTLGfx.h"

#if TARGET_OS_IOS
#import <Foundation/Foundation.h>
#import <MetalFX/MetalFX.h>
#import <dispatch/dispatch.h>
#endif
#ifdef IPHONEOS
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreVideo/CVMetalTextureCache.h>
#endif

#include "VideoBackends/Metal/MTLBoundingBox.h"
#include "VideoBackends/Metal/MTLObjectCache.h"
#include "VideoBackends/Metal/MTLPipeline.h"
#include "VideoBackends/Metal/MTLStateTracker.h"
#include "VideoBackends/Metal/MTLTexture.h"
#include "VideoBackends/Metal/MTLUtil.h"
#include "VideoBackends/Metal/MTLVertexFormat.h"
#include "VideoBackends/Metal/MTLVertexManager.h"

#include "VideoCommon/FramebufferManager.h"
#include "VideoCommon/Present.h"
#include "VideoCommon/VideoBackendBase.h"
#include "VideoCommon/VideoCommon.h"
#include "VideoCommon/VideoConfig.h"

#ifdef IPHONEOS
#include "Core/HW/DVD/NativeVideoDecoder.h"
#endif

#include <algorithm>
#include <cmath>
#include <fstream>

Metal::Gfx::Gfx(MRCOwned<CAMetalLayer*> layer) : m_layer(std::move(layer))
{
  UpdateActiveConfig();
#ifndef IPHONEOS
  [m_layer setDisplaySyncEnabled:g_ActiveConfig.bVSyncActive];
#endif

#ifdef IPHONEOS
  NativeVideoDecoder_Init();
#endif

  SetupSurface();
  g_state_tracker->FlushEncoders();
}

Metal::Gfx::~Gfx()
{
#if TARGET_OS_IOS
#ifdef IPHONEOS
  NativeVideoDecoder_Shutdown();
  if (m_native_video_texture_cache)
  {
    CVMetalTextureCacheFlush((CVMetalTextureCacheRef)m_native_video_texture_cache, 0);
    CFRelease((CVMetalTextureCacheRef)m_native_video_texture_cache);
    m_native_video_texture_cache = nullptr;
  }
  if (m_native_video_overlay_pipeline)
  {
    [(id)m_native_video_overlay_pipeline release];
    m_native_video_overlay_pipeline = nullptr;
  }
#endif
  if (m_metal_fx_scaler)
  {
    [(id)m_metal_fx_scaler release];
    m_metal_fx_scaler = nullptr;
  }
#endif
}

bool Metal::Gfx::IsHeadless() const
{
  return m_layer == nullptr;
}

// MARK: Texture Creation

static MTLTextureType FromAbstract(AbstractTextureType type, bool multisample)
{
  switch (type)
  {
  case AbstractTextureType::Texture_2D:
    return multisample ? MTLTextureType2DMultisample : MTLTextureType2D;
  case AbstractTextureType::Texture_2DArray:
    return multisample ? MTLTextureType2DMultisampleArray : MTLTextureType2DArray;
  case AbstractTextureType::Texture_CubeMap:
    return MTLTextureTypeCube;
  }

  ASSERT(false);
  return MTLTextureType2DArray;
}

std::unique_ptr<AbstractTexture> Metal::Gfx::CreateTexture(const TextureConfig& config,
                                                           std::string_view name)
{
  @autoreleasepool
  {
    MRCOwned<MTLTextureDescriptor*> desc = MRCTransfer([MTLTextureDescriptor new]);
    [desc setTextureType:FromAbstract(config.type, config.samples > 1)];
    [desc setPixelFormat:Util::FromAbstract(config.format)];
    [desc setWidth:config.width];
    [desc setHeight:config.height];
    [desc setMipmapLevelCount:config.levels];
    [desc setArrayLength:config.layers];
    [desc setSampleCount:config.samples];
    [desc setStorageMode:MTLStorageModePrivate];
    MTLTextureUsage usage = MTLTextureUsageShaderRead;
    if (config.IsRenderTarget())
      usage |= MTLTextureUsageRenderTarget;
    if (config.IsComputeImage())
      usage |= MTLTextureUsageShaderWrite;
    [desc setUsage:usage];
    id<MTLTexture> texture = [g_device newTextureWithDescriptor:desc];
    if (!texture)
      return nullptr;

    if (name.empty())
      [texture setLabel:[NSString stringWithFormat:@"Texture %d", m_texture_counter++]];
    else
      [texture setLabel:MRCTransfer([[NSString alloc] initWithBytes:name.data()
                                                             length:name.size()
                                                           encoding:NSUTF8StringEncoding])];
    return std::make_unique<Texture>(MRCTransfer(texture), config);
  }
}

std::unique_ptr<AbstractStagingTexture>
Metal::Gfx::CreateStagingTexture(StagingTextureType type, const TextureConfig& config)
{
  @autoreleasepool
  {
    const size_t stride = config.GetStride();
    const size_t buffer_size = stride * static_cast<size_t>(config.height);

    MTLResourceOptions options = MTLStorageModeShared;
    if (type == StagingTextureType::Upload)
      options |= MTLResourceCPUCacheModeWriteCombined;

    id<MTLBuffer> buffer = [g_device newBufferWithLength:buffer_size options:options];
    if (!buffer)
      return nullptr;
    [buffer
        setLabel:[NSString stringWithFormat:@"Staging Texture %d", m_staging_texture_counter++]];
    return std::make_unique<StagingTexture>(MRCTransfer(buffer), type, config);
  }
}

std::unique_ptr<AbstractFramebuffer>
Metal::Gfx::CreateFramebuffer(AbstractTexture* color_attachment, AbstractTexture* depth_attachment,
                              std::vector<AbstractTexture*> additional_color_attachments)
{
  AbstractTexture* const either_attachment = color_attachment ? color_attachment : depth_attachment;
  return std::make_unique<Framebuffer>(
      color_attachment, depth_attachment, std::move(additional_color_attachments),
      either_attachment->GetWidth(), either_attachment->GetHeight(), either_attachment->GetLayers(),
      either_attachment->GetSamples());
}

// MARK: Pipeline Creation

std::unique_ptr<AbstractShader> Metal::Gfx::CreateShaderFromSource(ShaderStage stage,
                                                                   std::string_view source,
                                                                   std::string_view name)
{
  std::optional<std::string> msl = Util::TranslateShaderToMSL(stage, source);
  if (!msl.has_value())
  {
    // Log detailed error for post-processing shaders to help diagnose issues
    if (name.find("post-processing") != std::string_view::npos)
    {
      ERROR_LOG_FMT(VIDEO, "Failed to compile post-processing shader: {}", name);
      ERROR_LOG_FMT(VIDEO, "Shader source (first 300 chars): {}", 
                    source.substr(0, std::min<size_t>(300, source.size())));
    }
    else
    {
      PanicAlertFmt("Failed to convert shader {} to MSL", name);
    }
    return nullptr;
  }

  return CreateShaderFromMSL(stage, std::move(*msl), source, name);
}

std::unique_ptr<AbstractShader> Metal::Gfx::CreateShaderFromBinary(ShaderStage stage,
                                                                   const void* data, size_t length,
                                                                   std::string_view name)
{
  return CreateShaderFromMSL(stage, std::string(static_cast<const char*>(data), length), {}, name);
}

std::optional<std::string> Metal::Gfx::TranslateSlangSPIRVToMSL(ShaderStage stage,
                                                                const std::vector<u32>& spirv) const
{
  return Util::TranslateSlangSPIRVToMSL(stage, spirv);
}

// clang-format off

static const char* StageFilename(ShaderStage stage)
{
  switch (stage)
  {
  case ShaderStage::Vertex:   return "vs";
  case ShaderStage::Geometry: return "gs";
  case ShaderStage::Pixel:    return "ps";
  case ShaderStage::Compute:  return "cs";
  }
}

static NSString* GenericShaderName(ShaderStage stage)
{
  switch (stage)
  {
  case ShaderStage::Vertex:   return @"Vertex shader %d";
  case ShaderStage::Geometry: return @"Geometry shader %d";
  case ShaderStage::Pixel:    return @"Pixel shader %d";
  case ShaderStage::Compute:  return @"Compute shader %d";
  }
}

// clang-format on

std::unique_ptr<AbstractShader> Metal::Gfx::CreateShaderFromMSL(ShaderStage stage, std::string msl,
                                                                std::string_view glsl,
                                                                std::string_view name)
{
  @autoreleasepool
  {
    NSError* err = nullptr;
    auto DumpBadShader = [&](std::string_view msg) {
      static int counter = 0;
      std::string filename = VideoBackendBase::BadShaderFilename(StageFilename(stage), counter++);
      std::ofstream stream(filename);
      if (stream.good())
      {
        stream << msl << std::endl;
        stream << "/*" << std::endl;
        stream << msg << std::endl;
        stream << "Error:" << std::endl;
        stream << [[err localizedDescription] UTF8String] << std::endl;
        if (!glsl.empty())
        {
          stream << "Original GLSL:" << std::endl;
          stream << glsl << std::endl;
        }
        else
        {
          stream << "Shader was created with cached MSL so no GLSL is available." << std::endl;
        }
      }

      stream << std::endl;
      stream << "Dolphin Version: " << Common::GetScmRevStr() << std::endl;
      stream << "Video Backend: " << g_video_backend->GetDisplayName() << std::endl;
      stream << "*/" << std::endl;
      stream.close();

      PanicAlertFmt("{} (written to {})\n", msg, filename);
    };

    auto lib = MRCTransfer([g_device newLibraryWithSource:[NSString stringWithUTF8String:msl.data()]
                                                  options:nil
                                                    error:&err]);
    if (err)
    {
      DumpBadShader(fmt::format("Failed to compile {}", name));
      return nullptr;
    }
    auto fn = MRCTransfer([lib newFunctionWithName:@"main0"]);
    if (!fn)
    {
      DumpBadShader(fmt::format("Shader {} is missing its main0 function", name));
      return nullptr;
    }
    if (!name.empty())
      [fn setLabel:MRCTransfer([[NSString alloc] initWithBytes:name.data()
                                                        length:name.size()
                                                      encoding:NSUTF8StringEncoding])];
    else
      [fn setLabel:[NSString stringWithFormat:GenericShaderName(stage),
                                              m_shader_counter[static_cast<u32>(stage)]++]];
    [lib setLabel:[fn label]];
    if (stage == ShaderStage::Compute)
    {
      MTLComputePipelineReflection* reflection = nullptr;
      auto desc = [MTLComputePipelineDescriptor new];
      [desc setComputeFunction:fn];
      [desc setLabel:[fn label]];
      MRCOwned<id<MTLComputePipelineState>> pipeline =
          MRCTransfer([g_device newComputePipelineStateWithDescriptor:desc
                                                              options:MTLPipelineOptionArgumentInfo
                                                           reflection:&reflection
                                                                error:&err]);
      if (err)
      {
        DumpBadShader(fmt::format("Failed to compile compute pipeline {}", name));
        return nullptr;
      }
      return std::make_unique<ComputePipeline>(stage, reflection, std::move(msl), std::move(fn),
                                               std::move(pipeline));
    }
    return std::make_unique<Shader>(stage, std::move(msl), std::move(fn));
  }
}

std::unique_ptr<NativeVertexFormat>
Metal::Gfx::CreateNativeVertexFormat(const PortableVertexDeclaration& vtx_decl)
{
  @autoreleasepool
  {
    return std::make_unique<VertexFormat>(vtx_decl);
  }
}

std::unique_ptr<AbstractPipeline> Metal::Gfx::CreatePipeline(const AbstractPipelineConfig& config,
                                                             const void* cache_data,
                                                             size_t cache_data_length)
{
  return g_object_cache->CreatePipeline(config);
}

void Metal::Gfx::Flush()
{
  @autoreleasepool
  {
    g_state_tracker->FlushEncoders();
  }
}

void Metal::Gfx::WaitForGPUIdle()
{
  @autoreleasepool
  {
    g_state_tracker->FlushEncoders();
    g_state_tracker->WaitForFlushedEncoders();
  }
}

void Metal::Gfx::OnConfigChanged(u32 bits)
{
  AbstractGfx::OnConfigChanged(bits);

#ifndef IPHONEOS
  if (bits & CONFIG_CHANGE_BIT_VSYNC)
    [m_layer setDisplaySyncEnabled:g_ActiveConfig.bVSyncActive];
#endif

  if (bits & CONFIG_CHANGE_BIT_ANISOTROPY)
  {
    g_object_cache->ReloadSamplers();
    g_state_tracker->ReloadSamplers();
  }

#if TARGET_OS_IOS
  // When internal resolution changes (EFB scale) or HDR output is toggled, recreate the surface so
  // the drawable/backbuffer size, pixel format (8‑bit vs RGBA16F), EDR flag, and Metal FX scaler
  // input update immediately. Without this, changing the HDR setting at runtime appears to do
  // nothing until some other event (like rotation) forces a surface re‑creation.
  if (bits & (CONFIG_CHANGE_BIT_TARGET_SIZE | CONFIG_CHANGE_BIT_HDR))
    SetupSurface();
#endif
}

void Metal::Gfx::ClearRegion(const MathUtil::Rectangle<int>& target_rc, bool color_enable,
                             bool alpha_enable, bool z_enable, u32 color, u32 z)
{
  u32 framebuffer_width = m_current_framebuffer->GetWidth();
  u32 framebuffer_height = m_current_framebuffer->GetHeight();
  // All Metal render passes are fullscreen, so we can only run a fast clear if the target is too
  if (target_rc == MathUtil::Rectangle<int>(0, 0, framebuffer_width, framebuffer_height))
  {
    // Determine whether the EFB has an alpha channel. If it doesn't, we can clear the alpha
    // channel to 0xFF. This hopefully allows us to use the fast path in most cases.
    if (bpmem.zcontrol.pixel_format == PixelFormat::RGB565_Z16 ||
        bpmem.zcontrol.pixel_format == PixelFormat::RGB8_Z24 ||
        bpmem.zcontrol.pixel_format == PixelFormat::Z24)
    {
      // Force alpha writes, and clear the alpha channel. This is different from the other backends,
      // where the existing values of the alpha channel are preserved.
      alpha_enable = true;
      color &= 0x00FFFFFF;
    }

    bool c_ok = (color_enable && alpha_enable) ||
                g_state_tracker->GetCurrentFramebuffer()->GetColorFormat() ==
                    AbstractTextureFormat::Undefined;
    bool z_ok = z_enable || g_state_tracker->GetCurrentFramebuffer()->GetDepthFormat() ==
                                AbstractTextureFormat::Undefined;
    if (c_ok && z_ok)
    {
      @autoreleasepool
      {
        // clang-format off
        MTLClearColor clear_color = MTLClearColorMake(
            static_cast<double>((color >> 16) & 0xFF) / 255.0,
            static_cast<double>((color >>  8) & 0xFF) / 255.0,
            static_cast<double>((color >>  0) & 0xFF) / 255.0,
            static_cast<double>((color >> 24) & 0xFF) / 255.0);
        // clang-format on
        float z_normalized = static_cast<float>(z & 0xFFFFFF) / 16777216.0f;
        if (!g_backend_info.bSupportsReversedDepthRange)
          z_normalized = 1.f - z_normalized;
        g_state_tracker->BeginClearRenderPass(clear_color, z_normalized);
        return;
      }
    }
  }

  g_state_tracker->EnableEncoderLabel(false);
  AbstractGfx::ClearRegion(target_rc, color_enable, alpha_enable, z_enable, color, z);
  g_state_tracker->EnableEncoderLabel(true);
}

void Metal::Gfx::SetPipeline(const AbstractPipeline* pipeline)
{
  g_state_tracker->SetPipeline(static_cast<const Pipeline*>(pipeline));
}

void Metal::Gfx::SetFramebuffer(AbstractFramebuffer* framebuffer)
{
  // Shouldn't be bound as a texture.
  if (AbstractTexture* color = framebuffer->GetColorAttachment())
    g_state_tracker->UnbindTexture(static_cast<Texture*>(color)->GetMTLTexture());
  if (AbstractTexture* depth = framebuffer->GetDepthAttachment())
    g_state_tracker->UnbindTexture(static_cast<Texture*>(depth)->GetMTLTexture());

  m_current_framebuffer = framebuffer;
  g_state_tracker->SetCurrentFramebuffer(static_cast<Framebuffer*>(framebuffer));
}

void Metal::Gfx::SetAndDiscardFramebuffer(AbstractFramebuffer* framebuffer)
{
  @autoreleasepool
  {
    SetFramebuffer(framebuffer);
    g_state_tracker->BeginRenderPass(MTLLoadActionDontCare);
  }
}

void Metal::Gfx::SetAndClearFramebuffer(AbstractFramebuffer* framebuffer,
                                        const ClearColor& color_value, float depth_value)
{
  @autoreleasepool
  {
    SetFramebuffer(framebuffer);
    MTLClearColor color =
        MTLClearColorMake(color_value[0], color_value[1], color_value[2], color_value[3]);
    g_state_tracker->BeginClearRenderPass(color, depth_value);
  }
}

void Metal::Gfx::SetScissorRect(const MathUtil::Rectangle<int>& rc)
{
  g_state_tracker->SetScissor(rc);
}

void Metal::Gfx::SetTexture(u32 index, const AbstractTexture* texture)
{
  g_state_tracker->SetTexture(
      index, texture ? static_cast<const Texture*>(texture)->GetMTLTexture() : nullptr);
}

void Metal::Gfx::SetSamplerState(u32 index, const SamplerState& state)
{
  g_state_tracker->SetSampler(index, state);
}

void Metal::Gfx::SetComputeImageTexture(u32 index, AbstractTexture* texture, bool read, bool write)
{
  g_state_tracker->SetTexture(index + VideoCommon::MAX_COMPUTE_SHADER_SAMPLERS,
                              texture ? static_cast<const Texture*>(texture)->GetMTLTexture() :
                                        nullptr);
}

void Metal::Gfx::UnbindTexture(const AbstractTexture* texture)
{
  g_state_tracker->UnbindTexture(static_cast<const Texture*>(texture)->GetMTLTexture());
}

void Metal::Gfx::SetViewport(float x, float y, float width, float height, float near_depth,
                             float far_depth)
{
  g_state_tracker->SetViewport(x, y, width, height, near_depth, far_depth);
}

void Metal::Gfx::Draw(u32 base_vertex, u32 num_vertices)
{
  @autoreleasepool
  {
    g_state_tracker->Draw(base_vertex, num_vertices);
  }
}

void Metal::Gfx::DrawIndexed(u32 base_index, u32 num_indices, u32 base_vertex)
{
  @autoreleasepool
  {
    g_state_tracker->DrawIndexed(base_index, num_indices, base_vertex);
  }
}

void Metal::Gfx::DispatchComputeShader(const AbstractShader* shader,  //
                                       u32 groupsize_x, u32 groupsize_y, u32 groupsize_z,
                                       u32 groups_x, u32 groups_y, u32 groups_z)
{
  @autoreleasepool
  {
    g_state_tracker->SetPipeline(static_cast<const ComputePipeline*>(shader));
    g_state_tracker->DispatchComputeShader(groupsize_x, groupsize_y, groupsize_z,  //
                                           groups_x, groups_y, groups_z);
  }
}

void Metal::Gfx::BindBackbufferLayerAccess()
{
#if TARGET_OS_IOS
  // Always detect layer size change (e.g. device rotation) so SetupSurface runs with new bounds
  {
    CGSize layer_size = [m_layer bounds].size;
    const float layer_scale = [m_layer contentsScale];
    u32 current_layer_w = static_cast<u32>(std::max(1.0, layer_size.width * layer_scale));
    u32 current_layer_h = static_cast<u32>(std::max(1.0, layer_size.height * layer_scale));
    if (current_layer_w != m_last_layer_width || current_layer_h != m_last_layer_height)
      SetupSurfaceImpl();
  }
  if (@available(iOS 16.0, *))
  {
    bool metal_fx_enabled = g_ActiveConfig.bMetalFXUpscaling;
    if (metal_fx_enabled != m_last_metal_fx_upscaling)
      SetupSurfaceImpl();
    else if (metal_fx_enabled && m_metal_fx_scaler != nullptr)
    {
      CGSize layer_size = [m_layer bounds].size;
      const float layer_scale = [m_layer contentsScale];
      u32 layer_w = static_cast<u32>(layer_size.width * layer_scale);
      u32 layer_h = static_cast<u32>(layer_size.height * layer_scale);
      u32 input_w = layer_w;
      u32 input_h = layer_h;
      int efb_scale = g_ActiveConfig.iEFBScale;
      if (efb_scale == 0)
      {
        if (g_framebuffer_manager && g_framebuffer_manager->GetEFBFramebuffer())
        {
          input_w = g_framebuffer_manager->GetEFBWidth();
          input_h = g_framebuffer_manager->GetEFBHeight();
        }
      }
      else if (efb_scale >= 1 && efb_scale <= 8)
      {
        input_w = EFB_WIDTH * static_cast<u32>(efb_scale);
        input_h = EFB_HEIGHT * static_cast<u32>(efb_scale);
      }
      u32 output_w = static_cast<u32>(std::round(input_w * 1.25));
      u32 output_h = static_cast<u32>(std::round(input_h * 1.25));
      if (input_w != m_last_metal_fx_input_width || input_h != m_last_metal_fx_input_height ||
          output_w != m_last_metal_fx_output_width || output_h != m_last_metal_fx_output_height)
        SetupSurfaceImpl();
    }
  }
#endif
  m_drawable = MRCRetain([m_layer nextDrawable]);
}

bool Metal::Gfx::BindBackbuffer(const ClearColor& clear_color)
{
  @autoreleasepool
  {
    g_Config.Refresh();
    UpdateActiveConfig();
    CheckForSurfaceChange();
    CheckForSurfaceResize();
#if TARGET_OS_IOS
    // Layer property access and nextDrawable must run on the main thread on iOS.
    if (![NSThread isMainThread])
    {
      dispatch_sync(dispatch_get_main_queue(), ^{
        BindBackbufferLayerAccess();
      });
    }
    else
#endif
    {
      BindBackbufferLayerAccess();
    }
    if (!m_drawable || ![m_drawable texture])
      return false;
    bool use_metal_fx = false;
#if TARGET_OS_IOS
    if (@available(iOS 16.0, *))
      use_metal_fx = g_ActiveConfig.bMetalFXUpscaling && (m_metal_fx_scaler != nullptr);
#endif
    id<MTLTexture> backbuffer_color = static_cast<Texture*>(m_bb_texture.get())->GetMTLTexture();
    if (use_metal_fx && backbuffer_color)
      m_backbuffer->UpdateBackbufferTexture(backbuffer_color);
    else
      m_backbuffer->UpdateBackbufferTexture([m_drawable texture]);
    SetAndClearFramebuffer(m_backbuffer.get(), clear_color);
    return true;
  }
}

#ifdef IPHONEOS
void Metal::Gfx::EnsureNativeVideoOverlayResources()
{
  if (m_native_video_texture_cache && m_native_video_overlay_pipeline)
    return;
  id<MTLDevice> device = Metal::g_device;
  if (!device)
    return;
  if (!m_native_video_texture_cache)
  {
    CVMetalTextureCacheRef cache = nullptr;
    if (CVMetalTextureCacheCreate(kCFAllocatorDefault, nullptr, device, nullptr, &cache) ==
        kCVReturnSuccess)
      m_native_video_texture_cache = (void*)cache;
  }
  if (!m_native_video_overlay_pipeline)
  {
    static const char* overlay_msl = R"(
      #include <metal_stdlib>
      using namespace metal;
      struct VertexOut { float4 pos [[position]]; float2 uv; };
      vertex VertexOut overlay_vs(uint vid [[vertex_id]]) {
        VertexOut o;
        o.pos = float4(vid & 1 ? 3 : -1, vid & 2 ? 3 : -1, 0, 1);
        o.uv = float2(vid & 1, vid & 2 ? 1 : 0);
        return o;
      }
      fragment float4 overlay_fs(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
        return tex.sample(s, in.uv);
      }
    )";
    NSError* err = nil;
    id<MTLLibrary> lib = [device newLibraryWithSource:[NSString stringWithUTF8String:overlay_msl]
                                               options:nil
                                                 error:&err];
    if (!lib)
      return;
    id<MTLFunction> vs = [lib newFunctionWithName:@"overlay_vs"];
    id<MTLFunction> fs = [lib newFunctionWithName:@"overlay_fs"];
    if (!vs || !fs)
      return;
    MTLRenderPipelineDescriptor* desc = [MTLRenderPipelineDescriptor new];
    [desc setVertexFunction:vs];
    [desc setFragmentFunction:fs];
    [[desc colorAttachments][0] setPixelFormat:MTLPixelFormatBGRA8Unorm];
    id<MTLRenderPipelineState> pipe = [device newRenderPipelineStateWithDescriptor:desc error:&err];
    if (pipe)
      m_native_video_overlay_pipeline = pipe;
  }
}

void Metal::Gfx::DrawNativeVideoOverlay(id<MTLTexture> drawable_texture)
{
  if (!NativeVideoDecoder_IsEnabled())
    return;
  void* frame = NativeVideoDecoder_GetCurrentFrame();
  if (!frame)
    return;
  CVPixelBufferRef pixel_buffer = (CVPixelBufferRef)frame;
  EnsureNativeVideoOverlayResources();
  if (!m_native_video_texture_cache || !m_native_video_overlay_pipeline || !drawable_texture)
  {
    CFRelease(pixel_buffer);
    return;
  }
  CVMetalTextureCacheRef cache = (CVMetalTextureCacheRef)m_native_video_texture_cache;
  CVMetalTextureRef cv_tex = nullptr;
  size_t width = CVPixelBufferGetWidth(pixel_buffer);
  size_t height = CVPixelBufferGetHeight(pixel_buffer);
  if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, pixel_buffer, nullptr,
                                                MTLPixelFormatBGRA8Unorm, width, height, 0,
                                                &cv_tex) != kCVReturnSuccess)
  {
    CFRelease(pixel_buffer);
    return;
  }
  CFRelease(pixel_buffer);
  id<MTLTexture> overlay_tex = CVMetalTextureGetTexture(cv_tex);
  CFRelease(cv_tex);
  if (!overlay_tex)
    return;
  MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor new];
  [[rp colorAttachments][0] setTexture:drawable_texture];
  [[rp colorAttachments][0] setLoadAction:MTLLoadActionLoad];
  [[rp colorAttachments][0] setStoreAction:MTLStoreActionStore];
  id<MTLCommandBuffer> cmd_buf = g_state_tracker->GetRenderCmdBuf();
  id<MTLRenderCommandEncoder> enc = [cmd_buf renderCommandEncoderWithDescriptor:rp];
  [enc setRenderPipelineState:(id<MTLRenderPipelineState>)m_native_video_overlay_pipeline];
  [enc setFragmentTexture:overlay_tex atIndex:0];
  [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  [enc endEncoding];
}
#endif

void Metal::Gfx::PresentBackbuffer()
{
  @autoreleasepool
  {
    g_state_tracker->EndRenderPass();
    if (!m_drawable)
    {
      g_state_tracker->FlushEncoders();
      return;
    }
    id<MTLTexture> drawable_texture = [m_drawable texture];
    bool use_metal_fx = false;
#if TARGET_OS_IOS
    if (@available(iOS 16.0, *))
      use_metal_fx = g_ActiveConfig.bMetalFXUpscaling && (m_metal_fx_scaler != nullptr);
#endif
    if (use_metal_fx && drawable_texture && m_bb_texture && static_cast<Texture*>(m_bb_texture.get())->GetMTLTexture())
    {
      id<MTLCommandBuffer> cmd_buf = g_state_tracker->GetRenderCmdBuf();
      id<MTLFXSpatialScaler> scaler = (id<MTLFXSpatialScaler>)m_metal_fx_scaler;
      SurfaceInfo info = GetSurfaceInfo();
      [scaler setColorTexture:static_cast<Texture*>(m_bb_texture.get())->GetMTLTexture()];
      [scaler setInputContentWidth:info.width];
      [scaler setInputContentHeight:info.height];
      [scaler setOutputTexture:drawable_texture];
      [scaler encodeToCommandBuffer:cmd_buf];
    }
#ifdef IPHONEOS
    if (drawable_texture)
      DrawNativeVideoOverlay(drawable_texture);
#endif
    // Clear backbuffer reference to drawable texture before presenting so it's not used after present.
    m_backbuffer->UpdateBackbufferTexture(nullptr);
    if (g_ActiveConfig.iUsePresentDrawable == TriState::On ||
        (g_ActiveConfig.iUsePresentDrawable == TriState::Auto && g_ActiveConfig.bVSyncActive))
      [g_state_tracker->GetRenderCmdBuf() presentDrawable:m_drawable];
    else
      [g_state_tracker->GetRenderCmdBuf()
          addScheduledHandler:[drawable = std::move(m_drawable)](id) { [drawable present]; }];
    m_drawable = nullptr;
    g_state_tracker->FlushEncoders();
  }
}

void Metal::Gfx::CheckForSurfaceChange()
{
  if (!g_presenter || !g_presenter->SurfaceChangedTestAndClear())
    return;
  m_layer = MRCRetain(static_cast<CAMetalLayer*>(g_presenter->GetNewSurfaceHandle()));
  SetupSurface();
}

void Metal::Gfx::CheckForSurfaceResize()
{
  if (!g_presenter || !g_presenter->SurfaceResizedTestAndClear())
    return;
  g_Config.Refresh();
  UpdateActiveConfig();
  SetupSurface();
}

void Metal::Gfx::SetupSurface()
{
  if (!m_layer)
    return;
#if TARGET_OS_IOS
  if (![NSThread isMainThread])
  {
    dispatch_sync(dispatch_get_main_queue(), ^{
      SetupSurfaceImpl();
    });
    return;
  }
#endif
  SetupSurfaceImpl();
}

void Metal::Gfx::SetupSurfaceImpl()
{
  if (!m_layer)
    return;
  CGSize layer_size = [m_layer bounds].size;
  const float scale = [m_layer contentsScale];
  u32 layer_width = static_cast<u32>(std::max(1.0, layer_size.width * scale));
  u32 layer_height = static_cast<u32>(std::max(1.0, layer_size.height * scale));

#if TARGET_OS_IOS
  // Real HDR path: when the user enables HDR in config, always render into a 16‑bit float
  // drawable and request extended dynamic range from the system. Some devices may clamp this
  // back to SDR internally, but from the emulator's point of view we are now rendering with
  // a linear RGBA16F backbuffer so HDR post‑processing shaders and tone mapping can behave
  // consistently even when EDR detection fails.
  if (g_ActiveConfig.bHDR)
  {
    [m_layer setWantsExtendedDynamicRangeContent:YES];
    [m_layer setPixelFormat:MTLPixelFormatRGBA16Float];
    CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearSRGB);
    [m_layer setColorspace:colorspace];
    CGColorSpaceRelease(colorspace);
  }
  else
  {
    [m_layer setWantsExtendedDynamicRangeContent:NO];
    [m_layer setPixelFormat:MTLPixelFormatBGRA8Unorm];
    [m_layer setColorspace:nil];
  }
#endif

  u32 output_width = layer_width;
  u32 output_height = layer_height;
  bool use_metal_fx = false;

#if TARGET_OS_IOS
  // Internal resolution (EFB scale) is used for rendering; drawable size must match the layer
  // (view) so the presenter's aspect/letterbox logic uses the real screen size. Otherwise
  // drawable would be game resolution (e.g. 1920x1584) and the system would scale it to the
  // view, producing wrong aspect in Stretch and "missing" screen.
  u32 internal_width = layer_width;
  u32 internal_height = layer_height;

  int efb_scale = g_ActiveConfig.iEFBScale;
  if (efb_scale == 0)  // Auto: determine from screen size
  {
    if (g_framebuffer_manager && g_framebuffer_manager->GetEFBFramebuffer())
    {
      internal_width = g_framebuffer_manager->GetEFBWidth();
      internal_height = g_framebuffer_manager->GetEFBHeight();
    }
  }
  else if (efb_scale >= 1 && efb_scale <= 8)
  {
    internal_width = EFB_WIDTH * static_cast<u32>(efb_scale);
    internal_height = EFB_HEIGHT * static_cast<u32>(efb_scale);
  }

  if (@available(iOS 16.0, *))
  {
    use_metal_fx = g_ActiveConfig.bMetalFXUpscaling;
  }
  // Drawable = layer (view) size so aspect ratio and Stretch/Fit apply to the actual screen.
  // When Metal FX is on we still use an offscreen buffer at 1.25x internal, then output to drawable.
  if (use_metal_fx)
  {
    output_width = static_cast<u32>(std::round(internal_width * 1.25));
    output_height = static_cast<u32>(std::round(internal_height * 1.25));
  }
  else if (efb_scale >= 4)
  {
    // 4x, 5x, 6x: use internal resolution for drawable so there's enough room for the higher-res output.
    output_width = internal_width;
    output_height = internal_height;
  }
  // When Metal FX is off and 1x–3x: keep drawable at layer size (output already set above).
#endif

  // On macOS / iOS with Metal FX: drawable = game output res. On iOS without Metal FX: drawable = layer (view) size for correct aspect.
  [m_layer setDrawableSize:CGSizeMake(static_cast<CGFloat>(output_width),
                                      static_cast<CGFloat>(output_height))];

  SurfaceInfo texture_info;
  texture_info = {output_width, output_height, scale, Util::ToAbstract([m_layer pixelFormat])};

  if (use_metal_fx)
  {
    MTLPixelFormat pixel_format = [m_layer pixelFormat];
    if (pixel_format == MTLPixelFormatInvalid)
      pixel_format = MTLPixelFormatBGRA8Unorm;
    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixel_format
                                                                                     width:internal_width
                                                                                    height:internal_height
                                                                                 mipmapped:NO];
    [desc setStorageMode:MTLStorageModePrivate];
    [desc setUsage:MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite];
    id<MTLTexture> tex = [g_device newTextureWithDescriptor:desc];
    if (tex)
    {
      TextureConfig cfg(internal_width, internal_height, 1, 1, 1,
                        Util::ToAbstract([m_layer pixelFormat]),
                        AbstractTextureFlag_RenderTarget, AbstractTextureType::Texture_2D);
      m_bb_texture = std::make_unique<Texture>(MRCTransfer(tex), cfg);
      texture_info = {internal_width, internal_height, scale,
                      Util::ToAbstract([m_layer pixelFormat])};
    }
    else
    {
      use_metal_fx = false;
      texture_info = {output_width, output_height, scale, Util::ToAbstract([m_layer pixelFormat])};
    }
  }
  if (!use_metal_fx)
  {
    TextureConfig cfg(texture_info.width, texture_info.height, 1, 1, 1, texture_info.format,
                      AbstractTextureFlag_RenderTarget, AbstractTextureType::Texture_2DArray);
    m_bb_texture = std::make_unique<Texture>(nullptr, cfg);
  }

  m_backbuffer = std::make_unique<Framebuffer>(
      m_bb_texture.get(), nullptr, std::vector<AbstractTexture*>{}, texture_info.width,
      texture_info.height, 1, 1);

  m_surface_info = texture_info;

#if TARGET_OS_IOS
  if (@available(iOS 16.0, *))
  {
    if (m_metal_fx_scaler)
    {
      [(id)m_metal_fx_scaler release];
      m_metal_fx_scaler = nullptr;
    }
    if (use_metal_fx && [MTLFXSpatialScalerDescriptor supportsDevice:g_device])
    {
      MTLPixelFormat pixel_format = [m_layer pixelFormat];
      if (pixel_format == MTLPixelFormatInvalid)
        pixel_format = MTLPixelFormatBGRA8Unorm;
      MTLFXSpatialScalerDescriptor* scaler_desc = [[MTLFXSpatialScalerDescriptor alloc] init];
      scaler_desc.inputWidth = internal_width;
      scaler_desc.inputHeight = internal_height;
      scaler_desc.outputWidth = output_width;
      scaler_desc.outputHeight = output_height;
      scaler_desc.colorTextureFormat = pixel_format;
      scaler_desc.outputTextureFormat = pixel_format;
      // HDR output (RGBA16Float): use linear color processing so extended range is preserved.
      if (pixel_format == MTLPixelFormatRGBA16Float)
        scaler_desc.colorProcessingMode = MTLFXSpatialScalerColorProcessingModeLinear;
      else
        scaler_desc.colorProcessingMode = MTLFXSpatialScalerColorProcessingModePerceptual;
      id<MTLFXSpatialScaler> scaler = [scaler_desc newSpatialScalerWithDevice:g_device];
      if (scaler)
        m_metal_fx_scaler = scaler;
      [scaler_desc release];
    }
    m_last_metal_fx_upscaling = use_metal_fx;
    if (use_metal_fx)
    {
      m_last_metal_fx_input_width = internal_width;
      m_last_metal_fx_input_height = internal_height;
      m_last_metal_fx_output_width = output_width;
      m_last_metal_fx_output_height = output_height;
    }
    else
    {
      m_last_metal_fx_input_width = 0;
      m_last_metal_fx_input_height = 0;
      m_last_metal_fx_output_width = 0;
      m_last_metal_fx_output_height = 0;
    }
  }
  m_last_layer_width = layer_width;
  m_last_layer_height = layer_height;
#endif

  if (g_presenter)
    g_presenter->SetBackbuffer(m_surface_info);
}

SurfaceInfo Metal::Gfx::GetSurfaceInfo() const
{
  if (m_surface_info.width && m_surface_info.height)
    return m_surface_info;

  if (!m_layer)  // Headless
    return {};

  CGSize size = [m_layer bounds].size;
  const float scale = [m_layer contentsScale];
  u32 layer_width = static_cast<u32>(std::max(1.0, size.width * scale));
  u32 layer_height = static_cast<u32>(std::max(1.0, size.height * scale));

#if TARGET_OS_IOS
  if (@available(iOS 16.0, *))
  {
    if (g_ActiveConfig.bMetalFXUpscaling)
    {
      // Metal FX spatial scaler input = internal resolution from config directly.
      u32 internal_width = layer_width;
      u32 internal_height = layer_height;
      
      int efb_scale = g_ActiveConfig.iEFBScale;
      if (efb_scale == 0)  // Auto
      {
        if (g_framebuffer_manager && g_framebuffer_manager->GetEFBFramebuffer())
        {
          internal_width = g_framebuffer_manager->GetEFBWidth();
          internal_height = g_framebuffer_manager->GetEFBHeight();
        }
      }
      else if (efb_scale >= 1 && efb_scale <= 8)
      {
        internal_width = EFB_WIDTH * static_cast<u32>(efb_scale);
        internal_height = EFB_HEIGHT * static_cast<u32>(efb_scale);
      }
      
      internal_width = std::max(1u, internal_width);
      internal_height = std::max(1u, internal_height);
      return {internal_width, internal_height, scale, Util::ToAbstract([m_layer pixelFormat])};
    }
  }
#endif

  return {layer_width, layer_height, scale, Util::ToAbstract([m_layer pixelFormat])};
}
