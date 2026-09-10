// Copyright 2008 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

namespace Core
{
class CPUThreadGuard;
}

namespace HLE_Misc
{
void UnimplementedFunction(const Core::CPUThreadGuard& guard);
void HBReload(const Core::CPUThreadGuard& guard);
void GeckoCodeHandlerICacheFlush(const Core::CPUThreadGuard& guard);
void GeckoReturnTrampoline(const Core::CPUThreadGuard& guard);
void HLE_FastSqrtf(const Core::CPUThreadGuard& guard);
void HLE_FastSinf(const Core::CPUThreadGuard& guard);
void HLE_FastCosf(const Core::CPUThreadGuard& guard);
void HLE_FastTanf(const Core::CPUThreadGuard& guard);
void HLE_FastSqrt(const Core::CPUThreadGuard& guard);
void HLE_FastSin(const Core::CPUThreadGuard& guard);
void HLE_FastCos(const Core::CPUThreadGuard& guard);
void HLE_FastTan(const Core::CPUThreadGuard& guard);
}  // namespace HLE_Misc
