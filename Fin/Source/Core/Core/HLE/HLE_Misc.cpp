// Copyright 2008 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "Core/HLE/HLE_Misc.h"

#include <cmath>

#include "Common/Common.h"
#include "Common/CommonTypes.h"
#include "Core/Core.h"
#include "Core/GeckoCode.h"
#include "Core/HW/CPU.h"
#include "Core/Host.h"
#include "Core/PowerPC/MMU.h"
#include "Core/PowerPC/PowerPC.h"
#include "Core/System.h"

namespace HLE_Misc
{
// If you just want to kill a function, one of the three following are usually appropriate.
// According to the PPC ABI, the return value is always in r3.
void UnimplementedFunction(const Core::CPUThreadGuard& guard)
{
  auto& system = guard.GetSystem();
  auto& ppc_state = system.GetPPCState();
  ppc_state.npc = LR(ppc_state);
}

void HBReload(const Core::CPUThreadGuard& guard)
{
  // There isn't much we can do. Just stop cleanly.
  auto& system = guard.GetSystem();
  system.GetCPU().Break();
  Host_Message(HostMessageID::WMUserStop);
}

void GeckoCodeHandlerICacheFlush(const Core::CPUThreadGuard& guard)
{
  auto& system = guard.GetSystem();
  auto& ppc_state = system.GetPPCState();
  auto& jit_interface = system.GetJitInterface();

  // Work around the codehandler not properly invalidating the icache, but
  // only the first few frames.
  // (Project M uses a conditional to only apply patches after something has
  // been read into memory, or such, so we do the first 5 frames.  More
  // robust alternative would be to actually detect memory writes, but that
  // would be even uglier.)
  u32 gch_gameid = PowerPC::MMU::HostRead_U32(guard, Gecko::INSTALLER_BASE_ADDRESS);
  if (gch_gameid - Gecko::MAGIC_GAMEID == 5)
  {
    return;
  }
  else if (gch_gameid - Gecko::MAGIC_GAMEID > 5)
  {
    gch_gameid = Gecko::MAGIC_GAMEID;
  }
  PowerPC::MMU::HostWrite_U32(guard, gch_gameid + 1, Gecko::INSTALLER_BASE_ADDRESS);

  ppc_state.iCache.Reset(jit_interface);
}

// Because Dolphin messes around with the CPU state instead of patching the game binary, we
// need a way to branch into the GCH from an arbitrary PC address. Branching is easy, returning
// back is the hard part. This HLE function acts as a trampoline that restores the original LR, SP,
// and PC before the magic, invisible BL instruction happened.
void GeckoReturnTrampoline(const Core::CPUThreadGuard& guard)
{
  auto& system = guard.GetSystem();
  auto& ppc_state = system.GetPPCState();

  // Stack frame is built in GeckoCode.cpp, Gecko::RunCodeHandler.
  const u32 SP = ppc_state.gpr[1];
  ppc_state.gpr[1] = PowerPC::MMU::HostRead_U32(guard, SP + 8);
  ppc_state.npc = PowerPC::MMU::HostRead_U32(guard, SP + 12);
  LR(ppc_state) = PowerPC::MMU::HostRead_U32(guard, SP + 16);
  ppc_state.cr.Set(PowerPC::MMU::HostRead_U32(guard, SP + 20));
  for (int i = 0; i < 14; ++i)
  {
    ppc_state.ps[i].SetBoth(PowerPC::MMU::HostRead_U64(guard, SP + 24 + 2 * i * sizeof(u64)),
                            PowerPC::MMU::HostRead_U64(guard, SP + 24 + (2 * i + 1) * sizeof(u64)));
  }
}

void HLE_FastSqrtf(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const float input = static_cast<float>(ppc_state.ps[1].PS0AsDouble());
  ppc_state.ps[1].SetPS0(static_cast<double>(std::sqrt(input)));
  ppc_state.npc = LR(ppc_state);
}

void HLE_FastSinf(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const float input = static_cast<float>(ppc_state.ps[1].PS0AsDouble());
  ppc_state.ps[1].SetPS0(static_cast<double>(std::sin(input)));
  ppc_state.npc = LR(ppc_state);
}

void HLE_FastCosf(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const float input = static_cast<float>(ppc_state.ps[1].PS0AsDouble());
  ppc_state.ps[1].SetPS0(static_cast<double>(std::cos(input)));
  ppc_state.npc = LR(ppc_state);
}

void HLE_FastTanf(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const float input = static_cast<float>(ppc_state.ps[1].PS0AsDouble());
  ppc_state.ps[1].SetPS0(static_cast<double>(std::tan(input)));
  ppc_state.npc = LR(ppc_state);
}

void HLE_FastSqrt(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const double input = ppc_state.ps[1].PS0AsDouble();
  ppc_state.ps[1].SetPS0(std::sqrt(input));
  ppc_state.npc = LR(ppc_state);
}

void HLE_FastSin(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const double input = ppc_state.ps[1].PS0AsDouble();
  ppc_state.ps[1].SetPS0(std::sin(input));
  ppc_state.npc = LR(ppc_state);
}

void HLE_FastCos(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const double input = ppc_state.ps[1].PS0AsDouble();
  ppc_state.ps[1].SetPS0(std::cos(input));
  ppc_state.npc = LR(ppc_state);
}

void HLE_FastTan(const Core::CPUThreadGuard& guard)
{
  auto& ppc_state = guard.GetSystem().GetPPCState();
  const double input = ppc_state.ps[1].PS0AsDouble();
  ppc_state.ps[1].SetPS0(std::tan(input));
  ppc_state.npc = LR(ppc_state);
}
}  // namespace HLE_Misc
