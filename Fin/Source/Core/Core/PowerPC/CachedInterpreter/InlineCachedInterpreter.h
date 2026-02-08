// Copyright 2024 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "Core/PowerPC/CachedInterpreter/CachedInterpreter.h"

// InlineCachedInterpreter: A high-performance variant of CachedInterpreter that
// always enables inline instruction execution and fastmem optimizations.
// This replaces the "Unsafe Swift Optimizations" config toggle with a dedicated
// CPU core selection, giving users a clear performance-vs-accuracy choice.
class InlineCachedInterpreter final : public CachedInterpreter
{
public:
  explicit InlineCachedInterpreter(Core::System& system);
  ~InlineCachedInterpreter() override;

  void Init() override;
  const char* GetName() const override { return "Inline-Cached Interpreter"; }
};
