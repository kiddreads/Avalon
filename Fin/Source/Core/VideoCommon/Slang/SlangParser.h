// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <map>
#include <set>
#include <string>
#include <string_view>
#include <vector>

namespace Slang
{
struct Parameter
{
  std::string identifier;
  std::string description;
  float initial = 0.0f;
  float min = 0.0f;
  float max = 0.0f;
  float step = 0.0f;
};

struct PassSource
{
  std::string vertex_source;
  std::string fragment_source;
  std::string format;     // e.g. R16G16B16A16_SFLOAT
  std::string name;       // from #pragma name
};

struct Pass
{
  std::string path;       // absolute path to .slang
  PassSource source;
};

struct Preset
{
  std::vector<Pass> passes;
  std::map<std::string, std::string> parameters;  // key=value from preset
  std::map<std::string, Parameter> shader_parameters;  // from #pragma parameter
};

class Parser
{
public:
  // Load a preset (.slangp) or a single .slang file. Returns false on failure and fills errors.
  static bool LoadPreset(const std::string& path, Preset* out_preset,
                         std::vector<std::string>* errors);

private:
  static bool LoadPresetInternal(const std::string& path, Preset* out_preset,
                                 std::set<std::string>* visited,
                                 std::vector<std::string>* errors);
  static bool LoadSlangFile(const std::string& path, Pass* out_pass,
                            std::set<std::string>* include_guard,
                            std::vector<std::string>* errors);
  static std::string ResolveIncludes(const std::string& base_dir, const std::string& code,
                                     std::set<std::string>* include_guard,
                                     std::vector<std::string>* errors);
};
}  // namespace Slang
