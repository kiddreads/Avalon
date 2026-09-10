// Copyright 2026 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "VideoCommon/Slang/SlangParser.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <sstream>

#include "Common/CommonPaths.h"
#include "Common/FileSearch.h"
#include "Common/FileUtil.h"
#include "Common/Logging/Log.h"
#include "Common/StringUtil.h"

namespace fs = std::filesystem;

namespace Slang
{
namespace
{
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
  return s.size() >= prefix.size() &&
         std::equal(prefix.begin(), prefix.end(), s.begin());
}

// Simple parser for `#pragma parameter IDENT "DESC" init min max [step]`
bool ParseParameterPragma(const std::string& line, Parameter* out_param)
{
  // naive tokenization
  std::istringstream in(line);
  std::string pragma, parameter, ident, desc;
  if (!(in >> pragma >> parameter >> ident))
    return false;
  if (pragma != "#pragma" || parameter != "parameter")
    return false;

  // description is quoted; read rest of line
  std::string rest;
  std::getline(in, rest);
  auto first_quote = rest.find('"');
  auto second_quote = rest.find('"', first_quote + 1);
  if (first_quote == std::string::npos || second_quote == std::string::npos)
    return false;
  desc = rest.substr(first_quote + 1, second_quote - first_quote - 1);

  std::istringstream vals(rest.substr(second_quote + 1));
  float init = 0.0f, min = 0.0f, max = 0.0f, step = 0.0f;
  if (!(vals >> init >> min >> max))
    return false;
  if (!(vals >> step))
    step = 0.0f;

  out_param->identifier = ident;
  out_param->description = desc;
  out_param->initial = init;
  out_param->min = min;
  out_param->max = max;
  out_param->step = step;
  return true;
}

void AppendError(std::vector<std::string>* errors, const std::string& msg)
{
  if (errors)
    errors->push_back(msg);
}

// Search for a .slang file by filename in the user and system Shaders directories (recursive).
std::string SearchForSlangFile(const std::string& filename)
{
  const std::string user_shaders = File::GetUserPath(D_SHADERS_IDX);
  const std::string sys_shaders = std::string(File::GetSysDirectory()) + SHADERS_DIR DIR_SEP;
  auto results = Common::DoFileSearch({user_shaders, sys_shaders}, {".slang"}, true);
  for (const auto& result : results)
  {
    // Compare just the filename portion
    size_t pos = result.find_last_of("/\\");
    std::string result_name = (pos == std::string::npos) ? result : result.substr(pos + 1);
    if (result_name == filename)
    {
      INFO_LOG_FMT(VIDEO, "Slang: found \"{}\" at {}", filename, result);
      return result;
    }
  }
  return {};
}
}  // namespace

bool Parser::LoadPreset(const std::string& path, Preset* out_preset,
                        std::vector<std::string>* errors)
{
  std::set<std::string> visited;
  return LoadPresetInternal(path, out_preset, &visited, errors);
}

bool Parser::LoadPresetInternal(const std::string& path, Preset* out_preset,
                                std::set<std::string>* visited,
                                std::vector<std::string>* errors)
{
  if (!out_preset)
    return false;

  fs::path abs_path = fs::absolute(path);
  std::string normalized = abs_path.lexically_normal().string();
  if (!visited->insert(normalized).second)
  {
    AppendError(errors, "Cyclic #reference detected: " + normalized);
    return false;
  }

  if (fs::path(path).extension() == ".slang")
  {
    Pass pass;
    std::set<std::string> include_guard;
    if (!LoadSlangFile(normalized, &pass, &include_guard, errors))
      return false;
    out_preset->passes.push_back(std::move(pass));
    return true;
  }

  std::string file_data;
  if (!File::ReadFileToString(normalized, file_data))
  {
    AppendError(errors, "Failed to read preset: " + normalized);
    return false;
  }

  fs::path base_dir = abs_path.parent_path();

  // Collect pass paths and key/values
  std::vector<std::string> pass_paths;
  std::istringstream in(file_data);
  std::string line;
  while (std::getline(in, line))
  {
    line = Trim(line);
    if (line.empty() || StartsWith(line, "//"))
      continue;

    if (StartsWith(line, "#reference"))
    {
      // form: #reference "path"
      auto first = line.find('"');
      auto second = line.find('"', first + 1);
      if (first != std::string::npos && second != std::string::npos && second > first + 1)
      {
        fs::path ref = base_dir / line.substr(first + 1, second - first - 1);
        if (!LoadPresetInternal(ref.string(), out_preset, visited, errors))
          return false;
      }
      continue;
    }

    // key = "value"
    auto eq = line.find('=');
    if (eq != std::string::npos)
    {
      std::string key = Trim(line.substr(0, eq));
      std::string val = Trim(line.substr(eq + 1));
      if (StartsWith(val, "\"") && val.size() >= 2 && val.back() == '"')
        val = val.substr(1, val.size() - 2);

      // Pass definitions: shader, shader0, shader1, etc. (not "shaders" which is the count)
      bool is_pass_key = (key == "shader");
      if (!is_pass_key && key.size() > 6 && key.compare(0, 6, "shader") == 0)
      {
        is_pass_key = true;
        for (size_t i = 6; i < key.size(); ++i)
        {
          if (!std::isdigit(static_cast<unsigned char>(key[i])))
          {
            is_pass_key = false;
            break;
          }
        }
      }
      if (is_pass_key)
      {
        fs::path shader_path = base_dir / val;
        std::string resolved = shader_path.lexically_normal().string();

        // If the relative path doesn't exist, search by filename in Shaders dirs
        if (!File::Exists(resolved))
        {
          std::string filename = fs::path(val).filename().string();
          if (!filename.empty())
          {
            WARN_LOG_FMT(VIDEO,
                         "Slang: \"{}\" not found at relative path \"{}\", searching for \"{}\"...",
                         path, resolved, filename);
            std::string found = SearchForSlangFile(filename);
            if (!found.empty())
              resolved = found;
          }
        }
        pass_paths.push_back(resolved);
      }
      else
      {
        out_preset->parameters[key] = val;
      }
    }
  }

  // Load passes declared in this preset
  for (const std::string& pass_path : pass_paths)
  {
    Pass pass;
    std::set<std::string> include_guard;
    if (!LoadSlangFile(pass_path, &pass, &include_guard, errors))
      return false;
    out_preset->passes.push_back(std::move(pass));
  }

  return true;
}

bool Parser::LoadSlangFile(const std::string& path, Pass* out_pass,
                           std::set<std::string>* include_guard,
                           std::vector<std::string>* errors)
{
  if (!out_pass)
    return false;

  std::string code;
  if (!File::ReadFileToString(path, code))
  {
    AppendError(errors, "Failed to read slang file: " + path);
    return false;
  }

  fs::path base_dir = fs::absolute(fs::path(path)).parent_path();
  std::string expanded = ResolveIncludes(base_dir.string(), code, include_guard, errors);
  if (expanded.empty())
    return false;

  std::ostringstream vertex, fragment;
  enum class Stage
  {
    Both,
    Vertex,
    Fragment
  } stage = Stage::Both;

  PassSource source;

  std::istringstream in(expanded);
  std::string line;
  while (std::getline(in, line))
  {
    std::string trimmed = Trim(line);

    if (StartsWith(trimmed, "#pragma"))
    {
      if (StartsWith(trimmed, "#pragma stage"))
      {
        if (trimmed.find("vertex") != std::string::npos)
          stage = Stage::Vertex;
        else if (trimmed.find("fragment") != std::string::npos)
          stage = Stage::Fragment;
        else
          stage = Stage::Both;
        continue;
      }
      if (StartsWith(trimmed, "#pragma format"))
      {
        // e.g. #pragma format R16G16B16A16_SFLOAT
        std::istringstream fmt(trimmed);
        std::string p, fmt_kw, fmt_val;
        fmt >> p >> fmt_kw >> fmt_val;
        if (!fmt_val.empty())
          source.format = fmt_val;
        continue;
      }
      if (StartsWith(trimmed, "#pragma name"))
      {
        std::istringstream fmt(trimmed);
        std::string p, name_kw, name_val;
        fmt >> p >> name_kw >> name_val;
        if (!name_val.empty())
          source.name = name_val;
        continue;
      }
      Parameter param;
      if (ParseParameterPragma(trimmed, &param))
      {
        // store in shader_parameters; preset-level merge done by caller
        source.name = source.name.empty() ? param.identifier : source.name;
      }
    }

    switch (stage)
    {
    case Stage::Both:
      vertex << line << "\n";
      fragment << line << "\n";
      break;
    case Stage::Vertex:
      vertex << line << "\n";
      break;
    case Stage::Fragment:
      fragment << line << "\n";
      break;
    }
  }

  out_pass->path = path;
  out_pass->source.vertex_source = vertex.str();
  out_pass->source.fragment_source = fragment.str();
  out_pass->source.format = source.format;
  out_pass->source.name = source.name;
  return true;
}

std::string Parser::ResolveIncludes(const std::string& base_dir, const std::string& code,
                                    std::set<std::string>* include_guard,
                                    std::vector<std::string>* errors)
{
  std::ostringstream out;
  std::istringstream in(code);
  std::string line;
  while (std::getline(in, line))
  {
    std::string trimmed = Trim(line);
    if (StartsWith(trimmed, "#include"))
    {
      auto first = trimmed.find('"');
      auto second = trimmed.find('"', first + 1);
      if (first == std::string::npos || second == std::string::npos || second <= first + 1)
      {
        AppendError(errors, "Malformed #include: " + line);
        continue;
      }
      std::string rel = trimmed.substr(first + 1, second - first - 1);
      fs::path inc_path = fs::path(base_dir) / rel;
      std::string abs = fs::absolute(inc_path).lexically_normal().string();
      if (include_guard && !include_guard->insert(abs).second)
        continue;  // already included

      std::string inc_data;
      if (!File::ReadFileToString(abs, inc_data))
      {
        AppendError(errors, "Failed to read include: " + abs);
        continue;
      }
      out << ResolveIncludes(fs::path(abs).parent_path().string(), inc_data, include_guard, errors);
    }
    else
    {
      out << line << "\n";
    }
  }
  return out.str();
}
}  // namespace Slang
