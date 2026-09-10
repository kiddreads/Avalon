// Copyright 2014 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "VideoCommon/PostProcessing.h"

#include <set>
#include <sstream>
#include <string>
#include <string_view>

#include <fmt/format.h>

#include "Common/Assert.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/Config/Config.h"
#include "Common/FileSearch.h"
#include "Common/FileUtil.h"
#include "Common/IniFile.h"
#include "Common/Logging/Log.h"
#include "Common/MsgHandler.h"
#include "Common/StringUtil.h"

#include "Core/Config/GraphicsSettings.h"
#include "Core/Core.h"

#include "VideoCommon/AbstractFramebuffer.h"
#include "VideoCommon/AbstractGfx.h"
#include "VideoCommon/AbstractPipeline.h"
#include "VideoCommon/AbstractShader.h"
#include "VideoCommon/AbstractTexture.h"
#include "VideoCommon/FramebufferManager.h"
#include "VideoCommon/Present.h"
#include "VideoCommon/ShaderCache.h"
#include "VideoCommon/Slang/MpvGlslParser.h"
#include "VideoCommon/VertexManagerBase.h"
#include "VideoCommon/VideoCommon.h"
#include "VideoCommon/VideoConfig.h"

namespace VideoCommon
{
static const char s_empty_pixel_shader[] = "void main() { SetOutput(Sample()); }\n";
static const char s_default_pixel_shader_name[] = "default_pre_post_process";

// Backend headers (e.g. Metal) inject their own #version; strip the user's so we don't get "must occur first".
static std::string StripLeadingVersion(std::string_view code)
{
  const char* p = code.data();
  const char* end = p + code.size();
  while (p != end && (*p == ' ' || *p == '\t'))
    ++p;
  if (p == end || *p != '#')
    return std::string(code);
  ++p;
  while (p != end && (*p == ' ' || *p == '\t'))
    ++p;
  if (end - p >= 7 && std::string_view(p, 7) == "version")
  {
    p += 7;
    while (p != end && *p != '\n' && *p != '\r')
      ++p;
    if (p != end && *p == '\r')
      ++p;
    if (p != end && *p == '\n')
      ++p;
    return std::string(p, end - p);
  }
  return std::string(code);
}

// Detect mpv/Anime4K-style multi-pass .glsl (//!HOOK, //!BIND, etc.). These cannot be
// compiled as a single fragment shader; we skip compilation and show a clear message.
static bool IsMpvOrAnime4KMultipassGlsl(std::string_view code)
{
  return code.find("//!HOOK") != std::string_view::npos ||
         code.find("//!BIND") != std::string_view::npos;
}

// Keep the highest quality possible to avoid losing quality on subtle gamma conversions.
// RGBA16F should have enough quality even if we store colors in gamma space on it.
static const AbstractTextureFormat s_intermediary_buffer_format = AbstractTextureFormat::RGBA16F;

// Extract just the filename from a path (everything after last / or \).
static std::string ExtractFilename(const std::string& path)
{
  size_t pos = path.find_last_of("/\\");
  if (pos == std::string::npos)
    return path;
  return path.substr(pos + 1);
}

// Search for a shader file by filename (e.g. "Foo.glsl") in user Shaders dir, system Shaders dir,
// and their subdirectories.  Returns the first match found, or empty string.
static std::string SearchForShaderFile(const std::string& filename)
{
  const std::string user_shaders = File::GetUserPath(D_SHADERS_IDX);
  const std::string sys_shaders = std::string(File::GetSysDirectory()) + SHADERS_DIR DIR_SEP;

  std::vector<std::string> dirs = {user_shaders, sys_shaders};
  auto results = Common::DoFileSearch(dirs, {".glsl"}, true);
  for (const auto& result : results)
  {
    // Use case-insensitive comparison so "fxaa" can find "FXAA.glsl"
    if (Common::CaseInsensitiveEquals(ExtractFilename(result), filename))
    {
      INFO_LOG_FMT(VIDEO, "Post-processing: found shader \"{}\" at {}", filename, result);
      return result;
    }
  }
  return {};
}

// Same as SearchForShaderFile but for a given extension (e.g. ".glslp"). Used to find presets in subdirs.
static std::string SearchForShaderFileWithExt(const std::string& basename, const std::string& ext)
{
  const std::string filename = basename + ext;
  const std::string user_shaders = File::GetUserPath(D_SHADERS_IDX);
  const std::string sys_shaders = std::string(File::GetSysDirectory()) + SHADERS_DIR DIR_SEP;

  std::vector<std::string> dirs = {user_shaders, sys_shaders};
  auto results = Common::DoFileSearch(dirs, {ext}, true);
  for (const auto& result : results)
  {
    // Use case-insensitive comparison for consistency
    if (Common::CaseInsensitiveEquals(ExtractFilename(result), filename))
      return result;
  }
  return {};
}

// Parse libretro .glslp preset: find first "shader0=..." and return path to that .glsl.
// First tries the path relative to the preset dir; if not found, searches by filename in
// the user/system Shaders directories recursively.
// Returns empty string if not found or invalid.
static std::string GetFirstShaderFromGlslp(const std::string& preset_path)
{
  std::string preset_data;
  if (!File::ReadFileToString(preset_path, preset_data))
    return {};
  const std::string base_dir = preset_path.substr(0, preset_path.find_last_of("/\\") + 1);
  std::istringstream in(preset_data);
  std::string line;
  while (std::getline(in, line))
  {
    // Trim and skip comments/blank
    size_t start = line.find_first_not_of(" \t\r\n");
    if (start == std::string::npos || line[start] == '#' || line[start] == '/')
      continue;
    size_t eq = line.find('=');
    if (eq == std::string::npos)
      continue;
    std::string key = line.substr(start, eq - start);
    // Trim key
    while (!key.empty() && (key.back() == ' ' || key.back() == '\t'))
      key.pop_back();
    if (key != "shader0")
      continue;
    std::string val = line.substr(eq + 1);
    start = val.find_first_not_of(" \t\r\n\"");
    if (start == std::string::npos)
      continue;
    size_t end = val.find('"', start);
    if (end != std::string::npos)
      val = val.substr(start, end - start);
    else
      val = val.substr(start);
    end = val.find_last_not_of(" \t\r\n\"");
    if (end != std::string::npos)
      val = val.substr(0, end + 1);
    if (val.empty())
      continue;

    // 1) Try the exact relative path from the preset directory
    std::string resolved = base_dir + val;
    if (File::Exists(resolved))
      return resolved;

    // 2) Relative path not found — search by filename in Shaders directories
    std::string filename = ExtractFilename(val);
    if (!filename.empty())
    {
      WARN_LOG_FMT(VIDEO,
                   "Post-processing: \"{}\" not found at relative path \"{}\", searching for \"{}\" "
                   "in Shaders directories...",
                   preset_path, resolved, filename);
      std::string found = SearchForShaderFile(filename);
      if (!found.empty())
        return found;
    }

    // Return the original resolved path so caller can log a useful error
    return resolved;
  }
  return {};
}

static bool LoadShaderFromFile(const std::string& shader, const std::string& sub_dir,
                               std::string& out_code)
{
  const std::string user_base = File::GetUserPath(D_SHADERS_IDX) + sub_dir + shader;
  const std::string sys_base = File::GetSysDirectory() + SHADERS_DIR DIR_SEP + sub_dir + shader;

  std::string path = user_base + ".glsl";
  if (!File::Exists(path))
    path = sys_base + ".glsl";

  if (File::Exists(path))
  {
    if (File::ReadFileToString(path, out_code))
      return true;
  }
  else
  {
    // Shader list can show names from subdirs (e.g. Anime4K/Anime4K_Darken_Fast.glsl); find by filename.
    std::string found_glsl = SearchForShaderFile(shader + ".glsl");
    if (!found_glsl.empty() && File::ReadFileToString(found_glsl, out_code))
      return true;
  }

  // Try .glslp (libretro preset): use first shader in the chain
  std::string glslp_path = user_base + ".glslp";
  if (!File::Exists(glslp_path))
    glslp_path = sys_base + ".glslp";
  if (!File::Exists(glslp_path))
    glslp_path = SearchForShaderFileWithExt(shader, ".glslp");
  if (!glslp_path.empty() && File::Exists(glslp_path))
  {
    std::string first_path = GetFirstShaderFromGlslp(glslp_path);
    if (!first_path.empty() && File::ReadFileToString(first_path, out_code))
      return true;
    WARN_LOG_FMT(VIDEO,
                 "Post-processing: \"{}\" .glslp preset: shader0 not found or unreadable. Expected "
                 "path (relative to preset): shader0's value, e.g. shaders/Name/Name.glsl → {}",
                 shader, first_path.empty() ? "(parse failed)" : first_path);
  }

  out_code = "";
  // Log missing shader only once per name per run to avoid log spam when config keeps referencing it.
  static std::set<std::string> s_logged_missing;
  if (s_logged_missing.insert(shader).second)
  {
    if (File::Exists(user_base + ".slang") || File::Exists(user_base + ".slangp") ||
        File::Exists(sys_base + ".slang") || File::Exists(sys_base + ".slangp"))
      WARN_LOG_FMT(VIDEO,
                   "Post-processing: \"{}\" has .slang/.slangp but no .glsl; only .glsl is applied.",
                   shader);
    else
      WARN_LOG_FMT(VIDEO,
                   "Post-processing shader not found: \"{}\". Searched User and Sys Shaders. Add "
                   ".glsl/.glslp/.slang/.slangp to User Shaders folder to use it.",
                   shader);
  }
  return false;
}

static bool TryLoadSlangRuntime(const std::string& shader_name,
                                std::unique_ptr<Slang::Runtime>* out_runtime)
{
  std::vector<std::string> search_paths = {
      File::GetUserPath(D_SHADERS_IDX) + shader_name + ".slangp",
      File::GetUserPath(D_SHADERS_IDX) + shader_name + ".slang",
      File::GetSysDirectory() + SHADERS_DIR DIR_SEP + shader_name + ".slangp",
      File::GetSysDirectory() + SHADERS_DIR DIR_SEP + shader_name + ".slang"};

  for (const auto& p : search_paths)
  {
    if (!File::Exists(p))
      continue;

    auto runtime = std::make_unique<Slang::Runtime>();
    std::vector<std::string> errors;
    if (runtime->LoadPreset(p, &errors))
    {
      *out_runtime = std::move(runtime);
      return true;
    }
    for (const auto& e : errors)
      WARN_LOG_FMT(VIDEO, "Slang load error: {}", e);
  }
  return false;
}

PostProcessingConfiguration::PostProcessingConfiguration() = default;

PostProcessingConfiguration::~PostProcessingConfiguration() = default;

void PostProcessingConfiguration::LoadShader(const std::string& shader)
{
  // Load the shader from the configuration if there isn't one sent to us.
  m_current_shader = shader;
  if (shader.empty())
  {
    LoadDefaultShader();
    return;
  }

  std::string sub_dir = "";

  if (g_Config.stereo_mode == StereoMode::Anaglyph)
  {
    sub_dir = ANAGLYPH_DIR DIR_SEP;
  }
  else if (g_Config.stereo_mode == StereoMode::Passive)
  {
    sub_dir = PASSIVE_DIR DIR_SEP;
  }

  std::string code;
  if (!LoadShaderFromFile(shader, sub_dir, code))
  {
    // Clear config so we don't keep trying a missing shader (e.g. libretro shaders not yet in User Shaders).
    Config::SetBaseOrCurrent(Config::GFX_ENHANCE_POST_SHADER, "");
    LoadDefaultShader();
    return;
  }

  LoadOptions(code);
  // Note that this will build the shaders with the custom options values users
  // might have set in the settings
  LoadOptionsConfiguration();
  m_current_shader_code = code;
}

void PostProcessingConfiguration::LoadDefaultShader()
{
  m_options.clear();
  m_any_options_dirty = false;
  m_current_shader = "";
  m_current_shader_code = s_empty_pixel_shader;
}

void PostProcessingConfiguration::LoadOptions(const std::string& code)
{
  const std::string config_start_delimiter = "[configuration]";
  const std::string config_end_delimiter = "[/configuration]";
  size_t configuration_start = code.find(config_start_delimiter);
  size_t configuration_end = code.find(config_end_delimiter);

  m_options.clear();
  m_any_options_dirty = true;

  if (configuration_start == std::string::npos || configuration_end == std::string::npos)
  {
    // Issue loading configuration or there isn't one.
    return;
  }

  std::string configuration_string =
      code.substr(configuration_start + config_start_delimiter.size(),
                  configuration_end - configuration_start - config_start_delimiter.size());

  std::istringstream in(configuration_string);

  struct GLSLStringOption
  {
    std::string m_type;
    std::vector<std::pair<std::string, std::string>> m_options;
  };

  std::vector<GLSLStringOption> option_strings;
  GLSLStringOption* current_strings = nullptr;
  std::string line_str;
  while (std::getline(in, line_str))
  {
    std::string_view line = line_str;

#ifndef _WIN32
    // Check for CRLF eol and convert it to LF
    if (!line.empty() && line.at(line.size() - 1) == '\r')
      line.remove_suffix(1);
#endif

    if (!line.empty())
    {
      if (line[0] == '[')
      {
        size_t endpos = line.find("]");

        if (endpos != std::string::npos)
        {
          // New section!
          std::string_view sub = line.substr(1, endpos - 1);
          option_strings.push_back({std::string(sub)});
          current_strings = &option_strings.back();
        }
      }
      else
      {
        if (current_strings)
        {
          std::string key, value;
          Common::IniFile::ParseLine(line, &key, &value);

          if (!(key.empty() && value.empty()))
            current_strings->m_options.emplace_back(key, value);
        }
      }
    }
  }

  for (const auto& it : option_strings)
  {
    ConfigurationOption option;
    option.m_dirty = true;

    if (it.m_type == "OptionBool")
      option.m_type = ConfigurationOption::OptionType::Bool;
    else if (it.m_type == "OptionRangeFloat")
      option.m_type = ConfigurationOption::OptionType::Float;
    else if (it.m_type == "OptionRangeInteger")
      option.m_type = ConfigurationOption::OptionType::Integer;

    for (const auto& string_option : it.m_options)
    {
      if (string_option.first == "GUIName")
      {
        option.m_gui_name = string_option.second;
      }
      else if (string_option.first == "OptionName")
      {
        option.m_option_name = string_option.second;
      }
      else if (string_option.first == "DependentOption")
      {
        option.m_dependent_option = string_option.second;
      }
      else if (string_option.first == "MinValue" || string_option.first == "MaxValue" ||
               string_option.first == "DefaultValue" || string_option.first == "StepAmount")
      {
        std::vector<s32>* output_integer = nullptr;
        std::vector<float>* output_float = nullptr;

        if (string_option.first == "MinValue")
        {
          output_integer = &option.m_integer_min_values;
          output_float = &option.m_float_min_values;
        }
        else if (string_option.first == "MaxValue")
        {
          output_integer = &option.m_integer_max_values;
          output_float = &option.m_float_max_values;
        }
        else if (string_option.first == "DefaultValue")
        {
          output_integer = &option.m_integer_values;
          output_float = &option.m_float_values;
        }
        else if (string_option.first == "StepAmount")
        {
          output_integer = &option.m_integer_step_values;
          output_float = &option.m_float_step_values;
        }

        if (option.m_type == ConfigurationOption::OptionType::Bool)
        {
          TryParse(string_option.second, &option.m_bool_value);
        }
        else if (option.m_type == ConfigurationOption::OptionType::Integer)
        {
          TryParseVector(string_option.second, output_integer);
          if (output_integer->size() > 4)
            output_integer->erase(output_integer->begin() + 4, output_integer->end());
        }
        else if (option.m_type == ConfigurationOption::OptionType::Float)
        {
          TryParseVector(string_option.second, output_float);
          if (output_float->size() > 4)
            output_float->erase(output_float->begin() + 4, output_float->end());
        }
      }
    }
    m_options[option.m_option_name] = option;
  }
}

void PostProcessingConfiguration::LoadOptionsConfiguration()
{
  Common::IniFile ini;
  ini.Load(File::GetUserPath(F_DOLPHINCONFIG_IDX));
  std::string section = m_current_shader + "-options";

  // We already expect all the options to be marked as "dirty" when we reach here
  for (auto& it : m_options)
  {
    switch (it.second.m_type)
    {
    case ConfigurationOption::OptionType::Bool:
      ini.GetOrCreateSection(section)->Get(it.second.m_option_name, &it.second.m_bool_value,
                                           it.second.m_bool_value);
      break;
    case ConfigurationOption::OptionType::Integer:
    {
      std::string value;
      ini.GetOrCreateSection(section)->Get(it.second.m_option_name, &value);
      if (!value.empty())
      {
        auto integer_values = it.second.m_integer_values;
        if (TryParseVector(value, &integer_values))
        {
          it.second.m_integer_values = integer_values;
        }
      }
    }
    break;
    case ConfigurationOption::OptionType::Float:
    {
      std::string value;
      ini.GetOrCreateSection(section)->Get(it.second.m_option_name, &value);
      if (!value.empty())
      {
        auto float_values = it.second.m_float_values;
        if (TryParseVector(value, &float_values))
        {
          it.second.m_float_values = float_values;
        }
      }
    }
    break;
    }
  }
}

void PostProcessingConfiguration::SaveOptionsConfiguration()
{
  Common::IniFile ini;
  ini.Load(File::GetUserPath(F_DOLPHINCONFIG_IDX));
  std::string section = m_current_shader + "-options";

  for (auto& it : m_options)
  {
    switch (it.second.m_type)
    {
    case ConfigurationOption::OptionType::Bool:
    {
      ini.GetOrCreateSection(section)->Set(it.second.m_option_name, it.second.m_bool_value);
    }
    break;
    case ConfigurationOption::OptionType::Integer:
    {
      std::string value;
      for (size_t i = 0; i < it.second.m_integer_values.size(); ++i)
      {
        value += fmt::format("{}{}", it.second.m_integer_values[i],
                             i == (it.second.m_integer_values.size() - 1) ? "" : ", ");
      }
      ini.GetOrCreateSection(section)->Set(it.second.m_option_name, value);
    }
    break;
    case ConfigurationOption::OptionType::Float:
    {
      std::ostringstream value;
      value.imbue(std::locale("C"));

      for (size_t i = 0; i < it.second.m_float_values.size(); ++i)
      {
        value << it.second.m_float_values[i];
        if (i != (it.second.m_float_values.size() - 1))
          value << ", ";
      }
      ini.GetOrCreateSection(section)->Set(it.second.m_option_name, value.str());
    }
    break;
    }
  }
  ini.Save(File::GetUserPath(F_DOLPHINCONFIG_IDX));
}

void PostProcessingConfiguration::SetOptionf(const std::string& option, int index, float value)
{
  auto it = m_options.find(option);

  it->second.m_float_values[index] = value;
  it->second.m_dirty = true;
  m_any_options_dirty = true;
}

void PostProcessingConfiguration::SetOptioni(const std::string& option, int index, s32 value)
{
  auto it = m_options.find(option);

  it->second.m_integer_values[index] = value;
  it->second.m_dirty = true;
  m_any_options_dirty = true;
}

void PostProcessingConfiguration::SetOptionb(const std::string& option, bool value)
{
  auto it = m_options.find(option);

  it->second.m_bool_value = value;
  it->second.m_dirty = true;
  m_any_options_dirty = true;
}

PostProcessing::PostProcessing()
{
  m_timer.Start();
}

PostProcessing::~PostProcessing()
{
  m_timer.Stop();
  m_slang_runtime.reset();
}

static std::vector<std::string> GetShaders(const std::string& sub_dir = "")
{
  // Include GLSL, GLSLP (libretro preset), and Slang formats; recursive so
  // e.g. Shaders/hdr/sony_megatron_v1_presets/*.slangp are discovered
  std::vector<std::string> paths =
      Common::DoFileSearch({File::GetUserPath(D_SHADERS_IDX) + sub_dir,
                            File::GetSysDirectory() + SHADERS_DIR DIR_SEP + sub_dir},
                           {".glsl", ".glslp", ".slang", ".slangp"}, true);
  std::set<std::string> name_set;
  std::vector<std::string> result;
  for (std::string path : paths)
  {
    std::string name;
    SplitPath(path, nullptr, &name, nullptr);
    if (name == s_default_pixel_shader_name)
      continue;
    if (name_set.insert(name).second)
      result.push_back(name);
  }
  return result;
}

std::vector<std::string> PostProcessing::GetShaderList()
{
  return GetShaders();
}

std::vector<std::string> PostProcessing::GetAnaglyphShaderList()
{
  return GetShaders(ANAGLYPH_DIR DIR_SEP);
}

std::vector<std::string> PostProcessing::GetPassiveShaderList()
{
  return GetShaders(PASSIVE_DIR DIR_SEP);
}

bool PostProcessing::Initialize(AbstractTextureFormat format)
{
  m_framebuffer_format = format;
  // CompilePixelShader() must be run first if configuration options are used.
  // Otherwise the UBO has a different member list between vertex and pixel
  // shaders, which is a link error on some backends.
  if (!CompilePixelShader() || !CompileVertexShader() || !CompilePipeline())
    return false;

  return true;
}

void PostProcessing::RecompileShader()
{
  // Note: for simplicity we already recompile all the shaders
  // and pipelines even if there might not be need to.

  m_default_pipeline.reset();
  m_pipeline.reset();
  m_default_pixel_shader.reset();
  m_pixel_shader.reset();
  m_default_vertex_shader.reset();
  m_vertex_shader.reset();
  m_slang_runtime.reset();
  m_slang_active = false;
  if (!CompilePixelShader())
    return;
  if (!CompileVertexShader())
    return;

  CompilePipeline();
}

void PostProcessing::RecompilePipeline()
{
  m_default_pipeline.reset();
  m_pipeline.reset();
  CompilePipeline();
}

bool PostProcessing::IsColorCorrectionActive() const
{
  // We can skip the color correction pass if none of these settings are on
  // (it might have still helped with gamma correct sampling, but it's not worth running it).
  return g_ActiveConfig.color_correction.bCorrectColorSpace ||
         g_ActiveConfig.color_correction.bCorrectGamma ||
         m_framebuffer_format == AbstractTextureFormat::RGBA16F;
}

bool PostProcessing::NeedsIntermediaryBuffer() const
{
  // If we have no user selected post process shader,
  // there's no point in having an intermediary buffer doing nothing.
  return !m_config.GetShader().empty();
}

void PostProcessing::BlitFromTexture(const MathUtil::Rectangle<int>& dst,
                                     const MathUtil::Rectangle<int>& src,
                                     const AbstractTexture* src_tex, int src_layer)
{
  if (m_slang_active && m_slang_runtime)
  {
    if (!m_slang_runtime->Blit(dst, src, src_tex))
    {
      WARN_LOG_FMT(VIDEO, "Slang runtime failed; falling back to default pipeline");
      m_slang_active = false;
    }
    else
    {
      return;
    }
  }

  const bool needs_color_correction = IsColorCorrectionActive();
  const bool needs_resampling =
      g_ActiveConfig.output_resampling_mode > OutputResamplingMode::Default;

  if (g_gfx->GetCurrentFramebuffer()->GetColorFormat() != m_framebuffer_format)
  {
    m_framebuffer_format = g_gfx->GetCurrentFramebuffer()->GetColorFormat();
    RecompilePipeline();
  }

  // By default all source layers will be copied into the respective target layers
  const bool copy_all_layers = src_layer < 0;
  src_layer = std::max(src_layer, 0);

  MathUtil::Rectangle<int> src_rect = src;
  g_gfx->SetSamplerState(0, RenderState::GetLinearSamplerState());
  g_gfx->SetSamplerState(1, RenderState::GetPointSamplerState());
  g_gfx->SetTexture(0, src_tex);
  g_gfx->SetTexture(1, src_tex);

  const bool needs_intermediary_buffer = NeedsIntermediaryBuffer();
  const bool needs_default_pipeline = needs_color_correction || needs_resampling;
  const AbstractPipeline* final_pipeline = m_pipeline.get();
  std::vector<u8>* uniform_staging_buffer = &m_default_uniform_staging_buffer;
  bool default_uniform_staging_buffer = true;
  const MathUtil::Rectangle<int> present_rect = g_presenter->GetTargetRectangle();

  // Skip post-processing when frame dimensions are invalid (avoids "Contradictory frame
  // constraints" / "Invalid frame dimension" from backends and UI when bounds are zero or
  // non-finite, e.g. during config UI or before the first resize).
  if (present_rect.GetWidth() <= 0 || present_rect.GetHeight() <= 0 ||
      dst.GetWidth() <= 0 || dst.GetHeight() <= 0)
    return;

  // Intermediary pass.
  // We draw to a high quality intermediary texture for a couple reasons:
  // -Consistently do high quality gamma corrected resampling (upscaling/downscaling)
  // -Keep quality for gamma and gamut conversions, and HDR output
  //  (low bit depths lose too much quality with gamma conversions)
  // -Keep the post process phase in linear space, to better operate with colors
  if (m_default_pipeline && needs_default_pipeline && needs_intermediary_buffer)
  {
    AbstractFramebuffer* const previous_framebuffer = g_gfx->GetCurrentFramebuffer();

    // We keep the min number of layers as the render target,
    // as in case of OpenGL, the source FBX will have two layers,
    // but we will render onto two separate frame buffers (one by one),
    // so it would be a waste to allocate two layers (see "bUsesExplictQuadBuffering").
    const u32 target_layers = copy_all_layers ? src_tex->GetLayers() : 1;

    const int raw_target_width =
        needs_resampling ? present_rect.GetWidth() : src_rect.GetWidth();
    const int raw_target_height =
        needs_resampling ? present_rect.GetHeight() : src_rect.GetHeight();
    if (raw_target_width <= 0 || raw_target_height <= 0)
    {
      m_intermediary_frame_buffer.reset();
      m_intermediary_color_texture.reset();
    }
    else
    {
      const u32 target_width = static_cast<u32>(raw_target_width);
      const u32 target_height = static_cast<u32>(raw_target_height);

      if (!m_intermediary_frame_buffer || !m_intermediary_color_texture ||
          m_intermediary_color_texture->GetWidth() != target_width ||
          m_intermediary_color_texture->GetHeight() != target_height ||
          m_intermediary_color_texture->GetLayers() != target_layers)
      {
        const TextureConfig intermediary_color_texture_config(
            target_width, target_height, 1, target_layers, src_tex->GetSamples(),
            s_intermediary_buffer_format, AbstractTextureFlag_RenderTarget,
            AbstractTextureType::Texture_2DArray);
        m_intermediary_color_texture = g_gfx->CreateTexture(intermediary_color_texture_config,
                                                            "Intermediary post process texture");

        m_intermediary_frame_buffer =
            g_gfx->CreateFramebuffer(m_intermediary_color_texture.get(), nullptr);
      }

    g_gfx->SetFramebuffer(m_intermediary_frame_buffer.get());

    FillUniformBuffer(src_rect, src_tex, src_layer, g_gfx->GetCurrentFramebuffer()->GetRect(),
                      present_rect, uniform_staging_buffer->data(), !default_uniform_staging_buffer,
                      true);
    g_vertex_manager->UploadUtilityUniforms(uniform_staging_buffer->data(),
                                            static_cast<u32>(uniform_staging_buffer->size()));

    g_gfx->SetViewportAndScissor(g_gfx->ConvertFramebufferRectangle(
        m_intermediary_color_texture->GetRect(), m_intermediary_frame_buffer.get()));
    g_gfx->SetPipeline(m_default_pipeline.get());
    g_gfx->Draw(0, 3);

    g_gfx->SetFramebuffer(previous_framebuffer);
    src_rect = m_intermediary_color_texture->GetRect();
    src_tex = m_intermediary_color_texture.get();
    g_gfx->SetTexture(0, src_tex);
    g_gfx->SetTexture(1, src_tex);
    // The "m_intermediary_color_texture" has already copied
    // from the specified source layer onto its first one.
    // If we query for a layer that the source texture doesn't have,
    // it will fall back on the first one anyway.
    src_layer = 0;
    uniform_staging_buffer = &m_uniform_staging_buffer;
    default_uniform_staging_buffer = false;
    }
  }
  else
  {
    // If we have no custom user shader selected, and color correction
    // is active, directly run the fixed pipeline shader instead of
    // doing two passes, with the second one doing nothing useful.
    if (m_default_pipeline && needs_default_pipeline)
    {
      final_pipeline = m_default_pipeline.get();
    }
    else
    {
      uniform_staging_buffer = &m_uniform_staging_buffer;
      default_uniform_staging_buffer = false;
    }

    m_intermediary_frame_buffer.reset();
    m_intermediary_color_texture.reset();
  }

  // TODO: ideally we'd do the user selected post process pass in the intermediary buffer in linear
  // space (instead of gamma space), so the shaders could act more accurately (and sample in linear
  // space), though that would break the look of some of current post processes we have, and thus is
  // better avoided for now.

  // Final pass, either a user selected shader or the default (fixed) shader.
  if (final_pipeline)
  {
    FillUniformBuffer(src_rect, src_tex, src_layer, g_gfx->GetCurrentFramebuffer()->GetRect(),
                      present_rect, uniform_staging_buffer->data(), !default_uniform_staging_buffer,
                      false);
    g_vertex_manager->UploadUtilityUniforms(uniform_staging_buffer->data(),
                                            static_cast<u32>(uniform_staging_buffer->size()));

    g_gfx->SetViewportAndScissor(
        g_gfx->ConvertFramebufferRectangle(dst, g_gfx->GetCurrentFramebuffer()));
    g_gfx->SetPipeline(final_pipeline);
    g_gfx->Draw(0, 3);
  }
}

std::string PostProcessing::GetUniformBufferHeader(bool user_post_process) const
{
  std::ostringstream ss;
  u32 unused_counter = 1;
  ss << "UBO_BINDING(std140, 1) uniform PSBlock {\n";

  // Builtin uniforms:

  ss << "  float4 resolution;\n";  // Source resolution
  ss << "  float4 target_resolution;\n";
  ss << "  float4 window_resolution;\n";
  // How many horizontal and vertical stereo views do we have? (set to 1 when we use layers instead)
  ss << "  int2 stereo_views;\n";
  ss << "  float4 src_rect;\n";
  // The first (but not necessarily only) source layer we target
  ss << "  int src_layer;\n";
  ss << "  uint time;\n";
  ss << "  int graphics_api;\n";
  // If true, it's an intermediary buffer (including the first), if false, it's the final one
  ss << "  int intermediary_buffer;\n";

  ss << "  int resampling_method;\n";
  ss << "  int correct_color_space;\n";
  ss << "  int game_color_space;\n";
  ss << "  int correct_gamma;\n";
  ss << "  float game_gamma;\n";
  ss << "  int sdr_display_gamma_sRGB;\n";
  ss << "  float sdr_display_custom_gamma;\n";
  ss << "  int linear_space_output;\n";
  ss << "  int hdr_output;\n";
  ss << "  float hdr_paper_white_nits;\n";
  ss << "  float hdr_sdr_white_nits;\n";
  ss << "  float exposure;\n";

  if (user_post_process)
  {
    ss << "\n";
    // Custom options/uniforms
    for (const auto& it : m_config.GetOptions())
    {
      if (it.second.m_type == PostProcessingConfiguration::ConfigurationOption::OptionType::Bool)
      {
        ss << fmt::format("  int {};\n", it.first);
        for (u32 i = 0; i < 3; i++)
          ss << "  int ubo_align_" << unused_counter++ << "_;\n";
      }
      else if (it.second.m_type ==
               PostProcessingConfiguration::ConfigurationOption::OptionType::Integer)
      {
        u32 count = static_cast<u32>(it.second.m_integer_values.size());
        if (count == 1)
          ss << fmt::format("  int {};\n", it.first);
        else
          ss << fmt::format("  int{} {};\n", count, it.first);

        for (u32 i = count; i < 4; i++)
          ss << "  int ubo_align_" << unused_counter++ << "_;\n";
      }
      else if (it.second.m_type ==
               PostProcessingConfiguration::ConfigurationOption::OptionType::Float)
      {
        u32 count = static_cast<u32>(it.second.m_float_values.size());
        if (count == 1)
          ss << fmt::format("  float {};\n", it.first);
        else
          ss << fmt::format("  float{} {};\n", count, it.first);

        for (u32 i = count; i < 4; i++)
          ss << "  float ubo_align_" << unused_counter++ << "_;\n";
      }
    }
  }

  ss << "};\n\n";
  return ss.str();
}

std::string PostProcessing::GetHeader(bool user_post_process) const
{
  std::ostringstream ss;
  ss << GetUniformBufferHeader(user_post_process);
  ss << "SAMPLER_BINDING(0) uniform sampler2DArray samp0;\n";
  ss << "SAMPLER_BINDING(1) uniform sampler2DArray samp1;\n";

  if (g_backend_info.bSupportsGeometryShaders)
  {
    ss << "VARYING_LOCATION(0) in VertexData {\n";
    ss << "  float3 v_tex0;\n";
    ss << "};\n";
  }
  else
  {
    ss << "VARYING_LOCATION(0) in float3 v_tex0;\n";
  }

  ss << "FRAGMENT_OUTPUT_LOCATION(0) out float4 ocol0;\n";

  ss << R"(
float4 Sample() { return texture(samp0, v_tex0); }
float4 SampleLocation(float2 location) { return texture(samp0, float3(location, float(v_tex0.z))); }
float4 SampleLayer(int layer) { return texture(samp0, float3(v_tex0.xy, float(layer))); }
#define SampleOffset(offset) textureOffset(samp0, v_tex0, offset)

float2 GetTargetResolution()
{
  return target_resolution.xy;
}

float2 GetInvTargetResolution()
{
  return target_resolution.zw;
}

float2 GetWindowResolution()
{
  return window_resolution.xy;
}

float2 GetInvWindowResolution()
{
  return window_resolution.zw;
}

float2 GetResolution()
{
  return resolution.xy;
}

float2 GetInvResolution()
{
  return resolution.zw;
}

float2 GetCoordinates()
{
  return v_tex0.xy;
}

float GetLayer()
{
  return v_tex0.z;
}

uint GetTime()
{
  return time;
}

void SetOutput(float4 color)
{
  ocol0 = color;
}

#define GetOption(x) (x)
#define OptionEnabled(x) ((x) != 0)
#define OptionDisabled(x) ((x) == 0)

// HDR / tone mapping helpers (when hdr_output != 0, Sample() may return values > 1.0).
// Exposure tone mapping: mapped = 1 - exp(-hdrColor * exposure). Parameter named exposure_val to avoid shadowing exp().
float3 ToneMapExposure(float3 hdrColor, float exposure_val) { return float3(1.0) - exp(-hdrColor * exposure_val); }
// Reinhard tone mapping: compress HDR into [0,1]
float3 ToneMapReinhard(float3 hdrColor) { return hdrColor / (hdrColor + float3(1.0)); }
// Gamma correction: linear -> display (e.g. gamma 2.2 for sRGB)
float3 GammaCorrect(float3 linearColor, float gamma) { return pow(linearColor, float3(1.0 / gamma)); }

)";
  return ss.str();
}

std::string PostProcessing::GetFooter() const
{
  return {};
}

static std::string GetVertexShaderBody()
{
  std::ostringstream ss;
  if (g_backend_info.bSupportsGeometryShaders)
  {
    ss << "VARYING_LOCATION(0) out VertexData {\n";
    ss << "  float3 v_tex0;\n";
    ss << "};\n";
  }
  else
  {
    ss << "VARYING_LOCATION(0) out float3 v_tex0;\n";
  }

  ss << "#define id gl_VertexID\n";
  ss << "#define opos gl_Position\n";
  ss << "void main() {\n";
  ss << "  v_tex0 = float3(float((id << 1) & 2), float(id & 2), 0.0f);\n";
  ss << "  opos = float4(v_tex0.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);\n";
  ss << "  v_tex0 = float3(src_rect.xy + (src_rect.zw * v_tex0.xy), float(src_layer));\n";

  // Vulkan Y needs to be inverted on every pass
  if (g_backend_info.api_type == APIType::Vulkan)
  {
    ss << "  opos.y = -opos.y;\n";
  }
  // OpenGL Y needs to be inverted in all passes except the last one
  else if (g_backend_info.api_type == APIType::OpenGL)
  {
    ss << "  if (intermediary_buffer != 0)\n";
    ss << "    opos.y = -opos.y;\n";
  }

  ss << "}\n";
  return ss.str();
}

bool PostProcessing::CompileVertexShader()
{
  std::ostringstream ss_default;
  ss_default << GetUniformBufferHeader(false);
  ss_default << GetVertexShaderBody();
  m_default_vertex_shader = g_gfx->CreateShaderFromSource(ShaderStage::Vertex, ss_default.str(),
                                                          "Default post-processing vertex shader");

  std::ostringstream ss;
  ss << GetUniformBufferHeader(true);
  ss << GetVertexShaderBody();
  m_vertex_shader =
      g_gfx->CreateShaderFromSource(ShaderStage::Vertex, ss.str(), "Post-processing vertex shader");

  if (!m_default_vertex_shader || !m_vertex_shader)
  {
    PanicAlertFmt("Failed to compile post-processing vertex shader");
    m_default_vertex_shader.reset();
    m_vertex_shader.reset();
    return false;
  }

  return true;
}

struct BuiltinUniforms
{
  // bools need to be represented as "s32"

  std::array<float, 4> source_resolution;
  std::array<float, 4> target_resolution;
  std::array<float, 4> window_resolution;
  std::array<float, 4> stereo_views;
  std::array<float, 4> src_rect;
  s32 src_layer;
  u32 time;
  s32 graphics_api;
  s32 intermediary_buffer;
  s32 resampling_method;
  s32 correct_color_space;
  s32 game_color_space;
  s32 correct_gamma;
  float game_gamma;
  s32 sdr_display_gamma_sRGB;
  float sdr_display_custom_gamma;
  s32 linear_space_output;
  s32 hdr_output;
  float hdr_paper_white_nits;
  float hdr_sdr_white_nits;
  float exposure;
};

size_t PostProcessing::CalculateUniformsSize(bool user_post_process) const
{
  // Allocate a vec4 for each uniform to simplify allocation.
  return sizeof(BuiltinUniforms) +
         (user_post_process ? m_config.GetOptions().size() : 0) * sizeof(float) * 4;
}

void PostProcessing::FillUniformBuffer(const MathUtil::Rectangle<int>& src,
                                       const AbstractTexture* src_tex, int src_layer,
                                       const MathUtil::Rectangle<int>& dst,
                                       const MathUtil::Rectangle<int>& wnd, u8* buffer,
                                       bool user_post_process, bool intermediary_buffer)
{
  const float rcp_src_width = 1.0f / src_tex->GetWidth();
  const float rcp_src_height = 1.0f / src_tex->GetHeight();

  BuiltinUniforms builtin_uniforms;
  builtin_uniforms.source_resolution = {static_cast<float>(src_tex->GetWidth()),
                                        static_cast<float>(src_tex->GetHeight()), rcp_src_width,
                                        rcp_src_height};
  builtin_uniforms.target_resolution = {
      static_cast<float>(dst.GetWidth()), static_cast<float>(dst.GetHeight()),
      1.0f / static_cast<float>(dst.GetWidth()), 1.0f / static_cast<float>(dst.GetHeight())};
  builtin_uniforms.window_resolution = {
      static_cast<float>(wnd.GetWidth()), static_cast<float>(wnd.GetHeight()),
      1.0f / static_cast<float>(wnd.GetWidth()), 1.0f / static_cast<float>(wnd.GetHeight())};
  builtin_uniforms.src_rect = {static_cast<float>(src.left) * rcp_src_width,
                               static_cast<float>(src.top) * rcp_src_height,
                               static_cast<float>(src.GetWidth()) * rcp_src_width,
                               static_cast<float>(src.GetHeight()) * rcp_src_height};
  builtin_uniforms.src_layer = static_cast<s32>(src_layer);
  builtin_uniforms.time = static_cast<u32>(m_timer.ElapsedMs());
  builtin_uniforms.graphics_api = static_cast<s32>(g_backend_info.api_type);
  builtin_uniforms.intermediary_buffer = static_cast<s32>(intermediary_buffer);

  builtin_uniforms.resampling_method = static_cast<s32>(g_ActiveConfig.output_resampling_mode);
  // Color correction related uniforms.
  // These are mainly used by the "m_default_pixel_shader",
  // but should also be accessible to all other shaders.
  builtin_uniforms.correct_color_space = g_ActiveConfig.color_correction.bCorrectColorSpace;
  builtin_uniforms.game_color_space =
      static_cast<int>(g_ActiveConfig.color_correction.game_color_space);
  builtin_uniforms.correct_gamma = g_ActiveConfig.color_correction.bCorrectGamma;
  builtin_uniforms.game_gamma = g_ActiveConfig.color_correction.fGameGamma;
  builtin_uniforms.sdr_display_gamma_sRGB = g_ActiveConfig.color_correction.bSDRDisplayGammaSRGB;
  builtin_uniforms.sdr_display_custom_gamma =
      g_ActiveConfig.color_correction.fSDRDisplayCustomGamma;
  // scRGB (RGBA16F) expects linear values as opposed to sRGB gamma
  builtin_uniforms.linear_space_output = m_framebuffer_format == AbstractTextureFormat::RGBA16F;
  // Only apply HDR paper-white scale when the display actually supports EDR. Otherwise we'd multiply
  // by ~2.5 and blow out whites on SDR/non-EDR displays (e.g. HDR option on but device has no EDR).
  builtin_uniforms.hdr_output =
      (m_framebuffer_format == AbstractTextureFormat::RGBA16F) && g_backend_info.bSupportsHDROutput;
  builtin_uniforms.hdr_paper_white_nits = g_ActiveConfig.color_correction.fHDRPaperWhiteNits;
  // A value of 1 1 1 usually matches 80 nits in HDR
  builtin_uniforms.hdr_sdr_white_nits = 80.f;
  builtin_uniforms.exposure = g_ActiveConfig.color_correction.fExposure;

  std::memcpy(buffer, &builtin_uniforms, sizeof(builtin_uniforms));
  buffer += sizeof(builtin_uniforms);

  // Don't include the custom pp shader options if they are not necessary,
  // having mismatching uniforms between different shaders can cause issues on some backends
  if (!user_post_process)
    return;

  for (auto& it : m_config.GetOptions())
  {
    union
    {
      u32 as_bool[4];
      s32 as_int[4];
      float as_float[4];
    } value = {};

    switch (it.second.m_type)
    {
    case PostProcessingConfiguration::ConfigurationOption::OptionType::Bool:
      value.as_bool[0] = it.second.m_bool_value ? 1 : 0;
      break;

    case PostProcessingConfiguration::ConfigurationOption::OptionType::Integer:
      ASSERT(it.second.m_integer_values.size() <= 4);
      std::copy_n(it.second.m_integer_values.begin(), it.second.m_integer_values.size(),
                  value.as_int);
      break;

    case PostProcessingConfiguration::ConfigurationOption::OptionType::Float:
      ASSERT(it.second.m_float_values.size() <= 4);
      std::copy_n(it.second.m_float_values.begin(), it.second.m_float_values.size(),
                  value.as_float);
      break;
    }

    it.second.m_dirty = false;

    std::memcpy(buffer, &value, sizeof(value));
    buffer += sizeof(value);
  }

  m_config.SetDirty(false);
}

bool PostProcessing::CompilePixelShader()
{
  m_default_pixel_shader.reset();
  m_pixel_shader.reset();
  m_slang_runtime.reset();

  // Generate GLSL and compile the new shaders:

  std::string default_pixel_shader_code;
  if (LoadShaderFromFile(s_default_pixel_shader_name, "", default_pixel_shader_code))
  {
    m_default_pixel_shader = g_gfx->CreateShaderFromSource(
        ShaderStage::Pixel,
        GetHeader(false) + StripLeadingVersion(default_pixel_shader_code) + GetFooter(),
        "Default post-processing pixel shader");
    // We continue even if all of this failed, it doesn't matter
    m_default_uniform_staging_buffer.resize(CalculateUniformsSize(false));
  }
  else
  {
    m_default_uniform_staging_buffer.resize(0);
  }

  m_config.LoadShader(g_ActiveConfig.sPostProcessingShader);
  // If GLSL load failed and Slang is available, activate Slang runtime.
  if (m_config.GetShader().empty())
  {
    std::unique_ptr<Slang::Runtime> slang;
    if (TryLoadSlangRuntime(g_ActiveConfig.sPostProcessingShader, &slang))
    {
      m_slang_runtime = std::move(slang);
      m_slang_active = true;
      // Slang path uses its own pipeline creation; skip GLSL pixel shader creation.
      m_uniform_staging_buffer.clear();
      return true;
    }
  }

  // mpv/Anime4K-style .glsl use //!HOOK, //!BIND, etc. and multiple passes in one file.
  // Parse them into individual Slang passes and run through the Slang runtime pipeline.
  const std::string_view shader_code = m_config.GetShaderCode();
  if (!m_config.GetShader().empty() && IsMpvOrAnime4KMultipassGlsl(shader_code))
  {
    // First try a companion .slangp if one exists
    std::unique_ptr<Slang::Runtime> slang;
    if (TryLoadSlangRuntime(g_ActiveConfig.sPostProcessingShader, &slang))
    {
      m_slang_runtime = std::move(slang);
      m_slang_active = true;
      m_uniform_staging_buffer.clear();
      return true;
    }

    // Parse the mpv multi-pass GLSL into Slang passes
    std::vector<Slang::Pass> mpv_passes;
    std::vector<std::string> mpv_errors;
    if (Slang::ParseMpvGlsl(shader_code, &mpv_passes, &mpv_errors))
    {
      auto runtime = std::make_unique<Slang::Runtime>();
      std::vector<std::string> build_errors;
      if (runtime->LoadPasses(mpv_passes, &build_errors))
      {
        m_slang_runtime = std::move(runtime);
        m_slang_active = true;
        m_uniform_staging_buffer.clear();
        Core::DisplayMessage(
            fmt::format("Anime4K shader \"{}\" loaded ({} passes)",
                        m_config.GetShader(), mpv_passes.size()),
            4000);
        return true;
      }
      for (const auto& e : build_errors)
        WARN_LOG_FMT(VIDEO, "Anime4K pipeline build error: {}", e);
    }
    for (const auto& e : mpv_errors)
      WARN_LOG_FMT(VIDEO, "Anime4K parse error: {}", e);

    // Fall back to default shader if mpv parsing/compilation failed
    Config::SetBaseOrCurrent(Config::GFX_ENHANCE_POST_SHADER, "");
    Core::DisplayMessage(
        fmt::format("Post-processing shader \"{}\" (Anime4K) failed to compile. "
                    "Check log for details.",
                    m_config.GetShader()),
        6000);
    m_config.LoadDefaultShader();
    m_pixel_shader = g_gfx->CreateShaderFromSource(
        ShaderStage::Pixel,
        GetHeader(true) + StripLeadingVersion(m_config.GetShaderCode()) + GetFooter(),
        "Default post-processing pixel shader");
    if (!m_pixel_shader)
    {
      m_uniform_staging_buffer.resize(0);
      return false;
    }
    m_uniform_staging_buffer.resize(CalculateUniformsSize(true));
    return true;
  }

  m_pixel_shader = g_gfx->CreateShaderFromSource(
      ShaderStage::Pixel,
      GetHeader(true) + StripLeadingVersion(m_config.GetShaderCode()) + GetFooter(),
      fmt::format("User post-processing pixel shader: {}", m_config.GetShader()));
  if (!m_pixel_shader)
  {
    const std::string failed_shader = m_config.GetShader();
    Config::SetBaseOrCurrent(Config::GFX_ENHANCE_POST_SHADER, "");
    Core::DisplayMessage(
        fmt::format("Post-processing shader \"{}\" isn't supported on this device and was disabled.",
                    failed_shader),
        5000);

    // Use default shader.
    m_config.LoadDefaultShader();
    m_pixel_shader = g_gfx->CreateShaderFromSource(
        ShaderStage::Pixel,
        GetHeader(true) + StripLeadingVersion(m_config.GetShaderCode()) + GetFooter(),
        "Default user post-processing pixel shader");
    if (!m_pixel_shader)
    {
      m_uniform_staging_buffer.resize(0);
      return false;
    }
  }

  m_uniform_staging_buffer.resize(CalculateUniformsSize(true));
  return true;
}

static bool UseGeometryShaderForPostProcess(bool is_intermediary_buffer)
{
  // We only return true on stereo modes that need to copy
  // both source texture layers into the target texture layers.
  // Any other case is handled manually with multiple copies, thus
  // it doesn't need a geom shader.
  switch (g_ActiveConfig.stereo_mode)
  {
  case StereoMode::QuadBuffer:
    return !g_backend_info.bUsesExplictQuadBuffering;
  case StereoMode::Anaglyph:
  case StereoMode::Passive:
    return is_intermediary_buffer;
  case StereoMode::SBS:
  case StereoMode::TAB:
  case StereoMode::Off:
  default:
    return false;
  }
}

bool PostProcessing::CompilePipeline()
{
  // Not needed. Some backends don't like making pipelines with no targets,
  // and in any case, we don't need to render anything if that happened.
  if (m_framebuffer_format == AbstractTextureFormat::Undefined)
    return true;

  if (m_slang_active)
    return true;

  // If this is true, the "m_default_pipeline" won't be the only one that runs
  const bool needs_intermediary_buffer = NeedsIntermediaryBuffer();

  AbstractPipelineConfig config = {};
  config.vertex_shader = m_default_vertex_shader.get();
  // This geometry shader will take care of reading both layer 0 and 1 on the source texture,
  // and writing to both layer 0 and 1 on the render target.
  config.geometry_shader = UseGeometryShaderForPostProcess(needs_intermediary_buffer) ?
                               g_shader_cache->GetTexcoordGeometryShader() :
                               nullptr;
  config.pixel_shader = m_default_pixel_shader.get();
  config.rasterization_state = RenderState::GetNoCullRasterizationState(PrimitiveType::Triangles);
  config.depth_state = RenderState::GetNoDepthTestingDepthState();
  config.blending_state = RenderState::GetNoBlendingBlendState();
  config.framebuffer_state = RenderState::GetColorFramebufferState(
      needs_intermediary_buffer ? s_intermediary_buffer_format : m_framebuffer_format);
  config.usage = AbstractPipelineUsage::Utility;
  // We continue even if it failed, it will be skipped later on
  if (config.pixel_shader)
    m_default_pipeline = g_gfx->CreatePipeline(config);

  config.vertex_shader = m_vertex_shader.get();
  config.geometry_shader = UseGeometryShaderForPostProcess(false) ?
                               g_shader_cache->GetTexcoordGeometryShader() :
                               nullptr;
  config.pixel_shader = m_pixel_shader.get();
  config.framebuffer_state = RenderState::GetColorFramebufferState(m_framebuffer_format);
  m_pipeline = g_gfx->CreatePipeline(config);
  if (!m_pipeline)
    return false;

  return true;
}
}  // namespace VideoCommon
