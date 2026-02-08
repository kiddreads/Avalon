// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "VideoCommon/Slang/MpvGlslParser.h"

#include <algorithm>
#include <cctype>
#include <set>
#include <sstream>
#include <string>

#include "Common/Logging/Log.h"

namespace Slang
{
namespace
{
struct MpvPassInfo
{
  std::string desc;
  std::string hook;                // e.g. "MAIN", "LUMA", "NATIVE"
  std::vector<std::string> binds;  // e.g. {"HOOKED", "LINELUMA"}
  std::string save;                // e.g. "conv2d_tf" or empty (writes to HOOKED)
  std::string width_expr;          // e.g. "MAIN.w" or "MAIN.w 2 *"
  std::string height_expr;         // e.g. "MAIN.h" or "MAIN.h 2 *"
  int components = 4;
  std::string when_expr;
  std::string body;  // GLSL body (everything that isn't a //! directive)
};

std::string Trim(std::string_view s)
{
  size_t start = 0;
  while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start])))
    ++start;
  size_t end = s.size();
  while (end > start && std::isspace(static_cast<unsigned char>(s[end - 1])))
    --end;
  return std::string(s.substr(start, end - start));
}

bool StartsWith(std::string_view s, std::string_view prefix)
{
  return s.size() >= prefix.size() && std::equal(prefix.begin(), prefix.end(), s.begin());
}

// Split the mpv .glsl file into individual pass blocks.
// Each block starts at a //!HOOK directive.
// Note: //!DESC typically appears *before* //!HOOK for each pass, so we buffer it.
std::vector<MpvPassInfo> SplitPasses(std::string_view code)
{
  std::vector<MpvPassInfo> passes;
  MpvPassInfo* current = nullptr;
  std::string pending_desc;  // DESC that appeared before the next HOOK

  // Manual line splitting to avoid std::getline / std::istringstream portability issues
  size_t pos = 0;
  while (pos < code.size())
  {
    size_t eol = code.find('\n', pos);
    if (eol == std::string_view::npos)
      eol = code.size();
    std::string line(code.substr(pos, eol - pos));
    pos = eol + 1;

    // Strip trailing \r for Windows line endings
    if (!line.empty() && line.back() == '\r')
      line.pop_back();

    std::string trimmed = Trim(line);

    // //!DESC always precedes the next //!HOOK; buffer it for the upcoming pass
    if (StartsWith(trimmed, "//!DESC"))
    {
      pending_desc = Trim(trimmed.substr(7));
      continue;
    }

    // Check for mpv directives
    if (StartsWith(trimmed, "//!HOOK"))
    {
      passes.emplace_back();
      current = &passes.back();
      current->hook = Trim(trimmed.substr(7));
      if (!pending_desc.empty())
      {
        current->desc = pending_desc;
        pending_desc.clear();
      }
      continue;
    }

    if (!current)
      continue;  // skip lines before first //!HOOK (license header etc.)

    if (StartsWith(trimmed, "//!BIND"))
    {
      current->binds.push_back(Trim(trimmed.substr(7)));
    }
    else if (StartsWith(trimmed, "//!SAVE"))
    {
      current->save = Trim(trimmed.substr(7));
    }
    else if (StartsWith(trimmed, "//!WIDTH"))
    {
      current->width_expr = Trim(trimmed.substr(8));
    }
    else if (StartsWith(trimmed, "//!HEIGHT"))
    {
      current->height_expr = Trim(trimmed.substr(9));
    }
    else if (StartsWith(trimmed, "//!COMPONENTS"))
    {
      std::string val = Trim(trimmed.substr(13));
      if (!val.empty())
        current->components = std::atoi(val.c_str());
    }
    else if (StartsWith(trimmed, "//!WHEN"))
    {
      current->when_expr = Trim(trimmed.substr(7));
    }
    else if (StartsWith(trimmed, "//!"))
    {
      // Unknown directive, skip
    }
    else
    {
      current->body += line + "\n";
    }
  }

  return passes;
}

// Collect all unique texture names referenced by all passes.
// "HOOKED" is an alias for whatever the pass hooks into.
// "MAIN" is the original input. Named textures come from //!SAVE.
std::set<std::string> CollectTextureNames(const std::vector<MpvPassInfo>& passes)
{
  std::set<std::string> names;
  names.insert("MAIN");
  for (const auto& p : passes)
  {
    names.insert(p.hook);
    for (const auto& b : p.binds)
      names.insert(b);
    if (!p.save.empty())
      names.insert(p.save);
  }
  return names;
}

// Generate a standalone GLSL 450 fragment shader for one mpv pass.
// We replace mpv built-in functions/variables with standard GLSL using a single
// sampler2D (binding 0) for the source texture, and uniforms for sizes.
//
// For the simplified Dolphin pipeline, each pass receives the previous pass's output
// as a single texture. The mpv texture aliasing (HOOKED, MAIN, named textures) is
// collapsed: all texture references sample from the same source (binding 0).
// This is correct for linear chains where each pass reads only from the previous output
// or from MAIN (which we chain through).
std::string GenerateFragmentShader(const MpvPassInfo& pass,
                                   const std::set<std::string>& all_textures)
{
  std::ostringstream fs;
  fs << "#version 450\n\n";

  // Uniforms matching the Slang runtime UBO layout
  fs << "layout(std140, set=0, binding=0) uniform UBO {\n";
  fs << "  mat4 MVP;\n";
  fs << "  vec4 SourceSize;\n";   // (w, h, 1/w, 1/h)
  fs << "  vec4 OutputSize;\n";   // (w, h, 1/w, 1/h)
  fs << "  vec4 FinalViewportSize;\n";
  fs << "  uint FrameCount;\n";
  fs << "  int FrameDirection;\n";
  fs << "  float Exposure;\n";
  fs << "  float HDROutput;\n";
  fs << "  vec2 _pad;\n";
  fs << "};\n\n";

  // Source texture
  fs << "layout(set=1, binding=0) uniform sampler2D Source;\n\n";

  // Input/output
  fs << "layout(location=0) in vec2 vTexCoord;\n";
  fs << "layout(location=0) out vec4 FragColor;\n\n";

  // Generate mpv-compatible helper macros for each bound texture name.
  // We use #define instead of global variables/functions because:
  // 1) GLSL 450 requires constant expressions for global variable initializers
  // 2) The user code uses #define macros that reference NAME_texOff etc.,
  //    and macros must expand to valid expressions (functions would need forward decl)
  // In our simplified pipeline, all textures map to the same Source sampler.
  std::set<std::string> emitted;

  auto emitTextureHelpers = [&](const std::string& name) {
    if (!emitted.insert(name).second)
      return;

    // NAME_pos → vTexCoord
    fs << "#define " << name << "_pos vTexCoord\n";
    // NAME_size → SourceSize.xy
    fs << "#define " << name << "_size SourceSize.xy\n";
    // NAME_pt → SourceSize.zw (1/size)
    fs << "#define " << name << "_pt SourceSize.zw\n";

    // NAME_tex(p) → texture(Source, p)
    fs << "#define " << name << "_tex(p) texture(Source, (p))\n";

    // NAME_texOff(o) → texture(Source, vTexCoord + (o) * SourceSize.zw)
    fs << "#define " << name << "_texOff(o) texture(Source, vTexCoord + (o) * SourceSize.zw)\n";

    fs << "\n";
  };

  // Emit helpers for HOOKED (always present implicitly)
  emitTextureHelpers("HOOKED");

  // Emit for all bound textures in this pass
  for (const auto& b : pass.binds)
    emitTextureHelpers(b);

  // Also emit for the hook target (e.g. MAIN)
  emitTextureHelpers(pass.hook);

  // Emit for any other texture names referenced in the body
  for (const auto& name : all_textures)
  {
    // Check if the body references this texture
    if (pass.body.find(name + "_tex") != std::string::npos ||
        pass.body.find(name + "_texOff") != std::string::npos ||
        pass.body.find(name + "_pos") != std::string::npos ||
        pass.body.find(name + "_size") != std::string::npos ||
        pass.body.find(name + "_pt") != std::string::npos)
    {
      emitTextureHelpers(name);
    }
  }

  // Insert the pass body (user GLSL code)
  fs << pass.body << "\n";

  // Generate main() that calls hook() — the mpv entry point
  fs << "void main() {\n";
  fs << "  FragColor = hook();\n";
  fs << "}\n";

  return fs.str();
}

// Generate a simple passthrough vertex shader for the Slang pipeline.
std::string GenerateVertexShader()
{
  std::ostringstream vs;
  vs << "#version 450\n\n";

  vs << "layout(std140, set=0, binding=0) uniform UBO {\n";
  vs << "  mat4 MVP;\n";
  vs << "  vec4 SourceSize;\n";
  vs << "  vec4 OutputSize;\n";
  vs << "  vec4 FinalViewportSize;\n";
  vs << "  uint FrameCount;\n";
  vs << "  int FrameDirection;\n";
  vs << "  float Exposure;\n";
  vs << "  float HDROutput;\n";
  vs << "  vec2 _pad;\n";
  vs << "};\n\n";

  vs << "layout(location=0) out vec2 vTexCoord;\n\n";

  vs << "void main() {\n";
  vs << "  // Full-screen triangle\n";
  vs << "  vTexCoord = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);\n";
  vs << "  gl_Position = vec4(vTexCoord * 2.0 - 1.0, 0.0, 1.0);\n";
  vs << "}\n";

  return vs.str();
}

}  // namespace

bool ParseMpvGlsl(std::string_view code, std::vector<Pass>* out_passes,
                  std::vector<std::string>* errors)
{
  if (!out_passes)
    return false;

  // Must contain mpv directives
  if (code.find("//!HOOK") == std::string_view::npos)
  {
    if (errors)
      errors->push_back("Not an mpv/Anime4K multi-pass GLSL shader (no //!HOOK found)");
    return false;
  }

  auto mpv_passes = SplitPasses(code);
  if (mpv_passes.empty())
  {
    if (errors)
      errors->push_back("No passes found in mpv GLSL shader");
    return false;
  }

  INFO_LOG_FMT(VIDEO, "MpvGlslParser: found {} passes in Anime4K shader", mpv_passes.size());

  auto all_textures = CollectTextureNames(mpv_passes);
  std::string vs_code = GenerateVertexShader();

  out_passes->clear();
  out_passes->reserve(mpv_passes.size());

  for (size_t i = 0; i < mpv_passes.size(); ++i)
  {
    const auto& mp = mpv_passes[i];

    // Skip passes with empty bodies
    std::string trimmed_body = Trim(mp.body);
    if (trimmed_body.empty())
    {
      WARN_LOG_FMT(VIDEO, "MpvGlslParser: skipping pass {} ({}) with empty body", i, mp.desc);
      continue;
    }

    // Check that the body contains a hook() function
    if (mp.body.find("hook()") == std::string::npos &&
        mp.body.find("hook(void)") == std::string::npos)
    {
      WARN_LOG_FMT(VIDEO, "MpvGlslParser: skipping pass {} ({}) — no hook() entry point", i,
                    mp.desc);
      continue;
    }

    Pass pass;
    pass.path = "mpv_pass_" + std::to_string(i);
    pass.source.vertex_source = vs_code;
    pass.source.fragment_source = GenerateFragmentShader(mp, all_textures);
    pass.source.format = "R16G16B16A16_SFLOAT";
    pass.source.name = mp.desc.empty() ? ("mpv_pass_" + std::to_string(i)) : mp.desc;

    INFO_LOG_FMT(VIDEO, "MpvGlslParser: pass {} \"{}\" hook={} save={} binds={}", i,
                 pass.source.name, mp.hook, mp.save.empty() ? "(HOOKED)" : mp.save,
                 mp.binds.size());

    out_passes->push_back(std::move(pass));
  }

  if (out_passes->empty())
  {
    if (errors)
      errors->push_back("No valid passes extracted from mpv GLSL shader");
    return false;
  }

  return true;
}
}  // namespace Slang

