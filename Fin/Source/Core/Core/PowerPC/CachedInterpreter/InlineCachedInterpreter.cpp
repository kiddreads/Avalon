// Copyright 2024 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "InlineCachedInterpreter.h"

InlineCachedInterpreter::InlineCachedInterpreter(Core::System& system)
    : CachedInterpreter(system)
{
}

InlineCachedInterpreter::~InlineCachedInterpreter() = default;

void InlineCachedInterpreter::Init()
{
  CachedInterpreter::Init();

  // Enable all inline optimizations unconditionally.
  // This is the key difference from the base CachedInterpreter:
  // - Inline execution of common ALU, load/store, branch instructions
  // - Fastmem direct host memory access (bypassing full MMU path)
  // - Fused compare+branch optimization
  m_inline_mode = true;
}
