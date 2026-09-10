// Copyright 2014 Dolphin Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "CachedInterpreter.h"

#include <bit>
#include <cstring>
#include <optional>
#include <span>
#include <sstream>
#include <utility>

#include <fmt/format.h>
#include <fmt/ostream.h>

#include "Common/CommonTypes.h"
#include "Common/Swap.h"
#include "Common/GekkoDisassembler.h"
#include "Common/Logging/Log.h"
#include "Core/Config/MainSettings.h"
#include "Core/ConfigManager.h"
#include "Core/Core.h"
#include "Core/CoreTiming.h"
#include "Core/Debugger/BranchWatch.h"
#include "Core/HLE/HLE.h"
#include "Core/HW/CPU.h"
#include "Core/HW/Memmap.h"
#include "Core/Host.h"
#include "Core/PowerPC/Gekko.h"
#include "Core/PowerPC/Interpreter/Interpreter.h"
#include "Core/PowerPC/Interpreter/ExceptionUtils.h"
#include "Core/PowerPC/Interpreter/Interpreter_FPUtils.h"
#include "Core/PowerPC/Jit64Common/Jit64Constants.h"
#include "Core/PowerPC/MMU.h"
#include "Core/PowerPC/PPCAnalyst.h"
#include "Core/PowerPC/PowerPC.h"
#include "Core/System.h"

namespace
{
constexpr bool FastCRBit(const PowerPC::PowerPCState& ppc_state, u32 bit)
{
  const u64 cr_val = ppc_state.cr.fields[bit >> 2];
  switch (bit & 3)
  {
  case 0:  // LT
    return (cr_val >> PowerPC::CR_EMU_LT_BIT) & 1;
  case 1:  // GT
    return static_cast<s64>(cr_val) > 0;
  case 2:  // EQ
    return (cr_val & 0xFFFFFFFF) == 0;
  case 3:  // SO
    return (cr_val >> PowerPC::CR_EMU_SO_BIT) & 1;
  default:
    return false;
  }
}

constexpr void UpdateCR0(PowerPC::PowerPCState& ppc_state, u32 value)
{
  const s64 sign_extended = s64{s32(value)};
  u64 cr_val = u64(sign_extended);
  if (value == 0)
    cr_val |= 1ULL << 63;
  cr_val = (cr_val & ~(1ULL << PowerPC::CR_EMU_SO_BIT)) |
           (u64{ppc_state.GetXER_SO()} << PowerPC::CR_EMU_SO_BIT);
  ppc_state.cr.fields[0] = cr_val;
}

inline bool Carry(u32 value1, u32 value2)
{
  return value2 > (~value1);
}
}  // namespace

CachedInterpreter::CachedInterpreter(Core::System& system)
    : JitBase(system), m_memory(system.GetMemory()), m_block_cache(*this)
{
}

CachedInterpreter::~CachedInterpreter() = default;

void CachedInterpreter::Init()
{
  InitFastmemArena();
  m_block_cache.Init();
  ResetFreeMemoryRanges();
  
  AllocCodeSpace(CODE_SIZE);

  jo.enableBlocklink = false;

  m_block_cache.Init();

  code_block.m_stats = &js.st;
  code_block.m_gpa = &js.gpa;
  code_block.m_fpa = &js.fpa;
}

void CachedInterpreter::Shutdown()
{
  m_block_cache.Shutdown();
}

void CachedInterpreter::ResetFastmemCache()
{
  for (auto& entry : m_fastmem_cache)
    entry.valid = false;
  m_fastmem_last.valid = false;
}

__attribute__((always_inline)) bool CachedInterpreter::TryGetFastmemHostPointer(u32 address, FastmemPointerInfo* out,
                                                 std::size_t access_size)
{
  if (jo.memcheck || m_accurate_cpu_cache_enabled || m_ppc_state.m_enable_dcache)
  {
    return false;
  }

  // Fast path for the common case where we are not using virtual addressing.
  u32 phys_address = address;
  if (m_ppc_state.msr.DR != 0)
  {
    const std::optional<u32> translated = m_mmu.GetTranslatedAddress(address);
    if (!translated)
      return false;
    phys_address = *translated;
  }

  constexpr u32 page_size = 0x1000;
  const u32 page_base = phys_address & ~(page_size - 1);
  const u32 offset = phys_address - page_base;
  if (offset + access_size > page_size)
    return false;

  auto& memory = m_memory;

  // Restrict fastmem to RAM/EXRAM regions only. This avoids probing MMIO and
  // other unmapped regions (which would trigger Unknown Pointer warnings).
  const u32 page_base_masked = page_base & 0x3FFFFFFF;
  const bool in_ram = (page_base_masked < memory.GetRamSizeReal()) &&
                      (page_base_masked + page_size <= memory.GetRamSizeReal());
  const bool has_exram = memory.GetExRamSizeReal() > 0;
  const bool in_exram = has_exram && ((page_base >> 28) == 0x1) &&
                        ((page_base & 0x0FFFFFFF) + page_size <= memory.GetExRamSizeReal());
  if (!in_ram && !in_exram)
    return false;

  u8* host_base = nullptr;
  if (m_fastmem_last.valid && m_fastmem_last.page_base == page_base)
  {
    host_base = m_fastmem_last.host_base;
  }

  if (!host_base)
  {
    const size_t slot_index = (page_base >> 12) & FASTMEM_CACHE_MASK;
    auto& slot = m_fastmem_cache[slot_index];
    if (slot.valid && slot.page_base == page_base)
    {
      host_base = slot.host_base;
    }
    else
    {
      if (in_ram)
      {
        u8* ram = memory.GetRAM();
        if (!ram)
          return false;
        const u32 ram_mask = memory.GetRamMask();
        const u32 ram_page_base = page_base & ram_mask;
        host_base = ram + ram_page_base;
      }
      else if (in_exram)
      {
        u8* exram = memory.GetEXRAM();
        if (!exram)
          return false;
        const u32 exram_page_base = page_base & 0x0FFFFFFF;
        host_base = exram + exram_page_base;
      }
      else
      {
        host_base = memory.GetPointerForRange(page_base, page_size);
        if (!host_base)
          return false;
      }
      slot = {page_base, host_base, true};
    }
  }

  m_fastmem_last = {page_base, host_base, true};
  out->host_base = host_base;
  out->offset = offset;
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemReadU32(u32 address, u32& value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u32)))
    return false;

  u32 raw = 0;
  std::memcpy(&raw, fastmem.host_base + fastmem.offset, sizeof(raw));
  value = Common::swap32(raw);
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemWriteU32(u32 address, u32 value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u32)))
    return false;

  const u32 raw = Common::swap32(value);
  std::memcpy(fastmem.host_base + fastmem.offset, &raw, sizeof(raw));
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemReadU64(u32 address, u64& value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u64)))
    return false;

  u64 raw = 0;
  std::memcpy(&raw, fastmem.host_base + fastmem.offset, sizeof(raw));
  value = Common::swap64(raw);
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemWriteU64(u32 address, u64 value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u64)))
    return false;

  const u64 raw = Common::swap64(value);
  std::memcpy(fastmem.host_base + fastmem.offset, &raw, sizeof(raw));
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemReadU16(u32 address, u32& value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u16)))
    return false;

  u16 raw = 0;
  std::memcpy(&raw, fastmem.host_base + fastmem.offset, sizeof(raw));
  value = Common::swap16(raw);
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemWriteU16(u32 address, u16 value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u16)))
    return false;

  const u16 raw = Common::swap16(value);
  std::memcpy(fastmem.host_base + fastmem.offset, &raw, sizeof(raw));
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemReadU8(u32 address, u32& value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u8)))
    return false;

  u8 raw = 0;
  std::memcpy(&raw, fastmem.host_base + fastmem.offset, sizeof(raw));
  value = raw;
  return true;
}

__attribute__((always_inline)) bool CachedInterpreter::TryFastmemWriteU8(u32 address, u8 value)
{
  FastmemPointerInfo fastmem{};
  if (!TryGetFastmemHostPointer(address, &fastmem, sizeof(u8)))
    return false;

  std::memcpy(fastmem.host_base + fastmem.offset, &value, sizeof(value));
  return true;
}
// Use always_inline to eliminate function call overhead in the hot loop
__attribute__((always_inline)) bool CachedInterpreter::TryInlineHotInstruction(bool write_pc,
                                                const CachedInterpreter::InterpretOperands& operands)
{
  if (!m_inline_mode)
    return false;
  
  const UGeckoInstruction inst = operands.inst;
  const u32 opcd = inst.OPCD;

  // Dispatch by primary opcode to avoid multiple function-pointer comparisons (faster hot path).
  switch (opcd)
  {
  case 4:   // PS (we inline ps_madd and variants)
  case 7:   // mulli
  case 8:   // subfic
  case 10:  // cmpli
  case 11:  // cmpi
  case 12:  // addic
  case 13:  // addic_rc
  case 14:  // addi
  case 15:  // addis
  case 16:  // bcx
  case 18:  // bx
  case 19:  // bclrx / bcctrx
  case 20:  // rlwimix
  case 21:  // rlwinmx
  case 23:  // rlwnmx
  case 24:  // ori
  case 25:  // oris
  case 26:  // xori
  case 27:  // xoris
  case 28:  // andi_rc
  case 29:  // andis_rc
  case 31:  // extended ALU/load/store
  case 32:  // lwz
  case 33:  // lwzu
  case 34:  // lbz
  case 35:  // lbzu
  case 36:  // stw
  case 37:  // stwu
  case 38:  // stb
  case 39:  // stbu
  case 40:  // lhz
  case 41:  // lhzu
  case 44:  // sth
  case 45:  // sthu
  case 48:  // lfs
  case 50:  // lfd
  case 51:  // lfdu
  case 52:  // stfs
  case 54:  // stfd
  case 55:  // stfdu
    break;
  default:
    return false;
  }


  if (opcd == 31)
  {
    const u32 subop = inst.SUBOP10;
    switch (subop)
    {
    case 0:    // cmp
    case 23:   // lwzx
    case 24:   // slwx
    case 26:   // cntlzwx
    case 28:   // andx
    case 32:   // cmpl
    case 40:   // subfx
    case 60:   // andcx
    case 75:   // mulhwux
    case 83:   // mfmsr
    case 87:   // lbzx
    case 104:  // negx
    case 124:  // norx
    case 151:  // stwx
    case 215:  // stbx
    case 266:  // addx
    case 279:  // lhzx
    case 316:  // xorx
    case 407:  // sthx
    case 412:  // orcx
    case 444:  // orx
    case 536:  // srwx
    case 778:  // addox
    case 824:  // srawix
    case 922:  // extshx
    case 954:  // extsbx
      break;
    default:
      return false;
    }
  }


  auto& ppc_state = m_ppc_state;
  if (write_pc)
  {
    ppc_state.pc = operands.current_pc;
    ppc_state.npc = operands.current_pc + 4;
  }

  const u32 address =
      inst.RA ? (ppc_state.gpr[inst.RA] + u32(inst.SIMM_16)) : u32(inst.SIMM_16);

  switch (opcd)
  {
  case 7:  // mulli
    ppc_state.gpr[inst.RD] = u32(s32(ppc_state.gpr[inst.RA]) * inst.SIMM_16);
    return true;

  case 8:  // subfic
  {
    const s32 a = s32(ppc_state.gpr[inst.RA]);
    const s32 imm = inst.SIMM_16;
    ppc_state.gpr[inst.RD] = u32(imm - a);
    ppc_state.SetCarry((a == 0) || (Carry(0 - u32(a), u32(imm))));
    return true;
  }

  case 10:  // cmpli
  {
    const u32 a = ppc_state.gpr[inst.RA];
    const u32 b = inst.UIMM;
    u32 cr_field;
    if (a < b)
      cr_field = PowerPC::CR_LT;
    else if (a > b)
      cr_field = PowerPC::CR_GT;
    else
      cr_field = PowerPC::CR_EQ;
    if (ppc_state.GetXER_SO())
      cr_field |= PowerPC::CR_SO;
    ppc_state.cr.SetField(inst.CRFD, cr_field);
    return true;
  }

  case 11:  // cmpi
  {
    const s32 a = static_cast<s32>(ppc_state.gpr[inst.RA]);
    const s32 b = static_cast<s32>(inst.SIMM_16);
    u32 cr_field;
    if (a < b)
      cr_field = PowerPC::CR_LT;
    else if (a > b)
      cr_field = PowerPC::CR_GT;
    else
      cr_field = PowerPC::CR_EQ;
    if (ppc_state.GetXER_SO())
      cr_field |= PowerPC::CR_SO;
    ppc_state.cr.SetField(inst.CRFD, cr_field);
    return true;
  }


  case 12:  // addic
  {
    const u32 a = ppc_state.gpr[inst.RA];
    const u32 imm = static_cast<u32>(static_cast<s32>(inst.SIMM_16));
    ppc_state.gpr[inst.RD] = a + imm;
    ppc_state.SetCarry(Carry(a, imm));
    return true;
  }

  case 13:  // addic_rc
  {
    const u32 a = ppc_state.gpr[inst.RA];
    const u32 imm = static_cast<u32>(static_cast<s32>(inst.SIMM_16));
    const u32 result = a + imm;
    ppc_state.gpr[inst.RD] = result;
    ppc_state.SetCarry(Carry(a, imm));
    UpdateCR0(ppc_state, result);
    return true;
  }

  case 14:  // addi
    if (inst.RA)
      ppc_state.gpr[inst.RD] = ppc_state.gpr[inst.RA] + u32(inst.SIMM_16);
    else
      ppc_state.gpr[inst.RD] = u32(inst.SIMM_16);
    return true;

  case 15:  // addis
    if (inst.RA)
      ppc_state.gpr[inst.RD] = ppc_state.gpr[inst.RA] + u32(inst.SIMM_16 << 16);
    else
      ppc_state.gpr[inst.RD] = u32(inst.SIMM_16 << 16);
    return true;

  case 20:  // rlwimix
  {
    const u32 mask = MakeRotationMask(inst.MB, inst.ME);
    const u32 old = ppc_state.gpr[inst.RA];
    const u32 rotated = std::rotl(ppc_state.gpr[inst.RS], inst.SH);
    const u32 result = (old & ~mask) | (rotated & mask);
    ppc_state.gpr[inst.RA] = result;
    if (inst.Rc)
      UpdateCR0(ppc_state, result);
    return true;
  }

  case 21:  // rlwinmx
  {
    const u32 mask = MakeRotationMask(inst.MB, inst.ME);
    const u32 result = std::rotl(ppc_state.gpr[inst.RS], inst.SH) & mask;
    ppc_state.gpr[inst.RA] = result;
    if (inst.Rc)
      UpdateCR0(ppc_state, result);
    return true;
  }

  case 23:  // rlwnmx
  {
    const u32 mask = MakeRotationMask(inst.MB, inst.ME);
    const u32 result = std::rotl(ppc_state.gpr[inst.RS], ppc_state.gpr[inst.RB] & 0x1F) & mask;
    ppc_state.gpr[inst.RA] = result;
    if (inst.Rc)
      UpdateCR0(ppc_state, result);
    return true;
  }

  case 31:  // extended ALU/load/store
  {
    const u32 subop = inst.SUBOP10;
    const u32 ea_x = inst.RA ? (ppc_state.gpr[inst.RA] + ppc_state.gpr[inst.RB])
                              : ppc_state.gpr[inst.RB];
    switch (subop)
    {
    case 0:  // cmp
    {
      const s32 a = static_cast<s32>(ppc_state.gpr[inst.RA]);
      const s32 b = static_cast<s32>(ppc_state.gpr[inst.RB]);
      u32 cr_field;
      if (a < b)
        cr_field = PowerPC::CR_LT;
      else if (a > b)
        cr_field = PowerPC::CR_GT;
      else
        cr_field = PowerPC::CR_EQ;
      if (ppc_state.GetXER_SO())
        cr_field |= PowerPC::CR_SO;
      ppc_state.cr.SetField(inst.CRFD, cr_field);
      return true;
    }
    case 32:  // cmpl
    {
      const u32 a = ppc_state.gpr[inst.RA];
      const u32 b = ppc_state.gpr[inst.RB];
      u32 cr_field;
      if (a < b)
        cr_field = PowerPC::CR_LT;
      else if (a > b)
        cr_field = PowerPC::CR_GT;
      else
        cr_field = PowerPC::CR_EQ;
      if (ppc_state.GetXER_SO())
        cr_field |= PowerPC::CR_SO;
      ppc_state.cr.SetField(inst.CRFD, cr_field);
      return true;
    }
    case 266:  // addx
    case 778:  // addox
    {
      const u32 a = ppc_state.gpr[inst.RA];
      const u32 b = ppc_state.gpr[inst.RB];
      const u32 result = a + b;
      ppc_state.gpr[inst.RD] = result;
      if (inst.OE)
        ppc_state.SetXER_OV((((a ^ result) & (b ^ result)) >> 31) != 0);
      if (inst.Rc)
        UpdateCR0(ppc_state, result);
      return true;
    }
    case 40:  // subfx
    {
      const u32 a = ppc_state.gpr[inst.RA];
      const u32 b = ppc_state.gpr[inst.RB];
      const u32 result = b - a;
      ppc_state.gpr[inst.RD] = result;
      if (inst.OE)
        ppc_state.SetXER_OV((((b ^ a) & (b ^ result)) >> 31) != 0);
      if (inst.Rc)
        UpdateCR0(ppc_state, result);
      return true;
    }
    case 104:  // negx
    {
      const u32 a = ppc_state.gpr[inst.RA];
      const u32 result = (~a) + 1;
      ppc_state.gpr[inst.RD] = result;
      if (inst.OE)
        ppc_state.SetXER_OV(a == 0x80000000);
      if (inst.Rc)
        UpdateCR0(ppc_state, result);
      return true;
    }
    case 444:  // orx
      ppc_state.gpr[inst.RA] = ppc_state.gpr[inst.RS] | ppc_state.gpr[inst.RB];
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 28:  // andx
      ppc_state.gpr[inst.RA] = ppc_state.gpr[inst.RS] & ppc_state.gpr[inst.RB];
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 316:  // xorx
      ppc_state.gpr[inst.RA] = ppc_state.gpr[inst.RS] ^ ppc_state.gpr[inst.RB];
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 124:  // norx
      ppc_state.gpr[inst.RA] = ~(ppc_state.gpr[inst.RS] | ppc_state.gpr[inst.RB]);
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 60:  // andcx
      ppc_state.gpr[inst.RA] = ppc_state.gpr[inst.RS] & ~ppc_state.gpr[inst.RB];
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 412:  // orcx
      ppc_state.gpr[inst.RA] = ppc_state.gpr[inst.RS] | (~ppc_state.gpr[inst.RB]);
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 26:  // cntlzwx
      ppc_state.gpr[inst.RA] = u32(std::countl_zero(ppc_state.gpr[inst.RS]));
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 922:  // extshx
      ppc_state.gpr[inst.RA] = u32(s32(s16(ppc_state.gpr[inst.RS])));
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 954:  // extsbx
      ppc_state.gpr[inst.RA] = u32(s32(s8(ppc_state.gpr[inst.RS])));
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    case 24:  // slwx
    {
      const u32 amount = ppc_state.gpr[inst.RB];
      ppc_state.gpr[inst.RA] = (amount & 0x20) ? 0 : ppc_state.gpr[inst.RS] << (amount & 0x1f);
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    }
    case 536:  // srwx
    {
      const u32 amount = ppc_state.gpr[inst.RB];
      ppc_state.gpr[inst.RA] = (amount & 0x20) ? 0 : (ppc_state.gpr[inst.RS] >> (amount & 0x1f));
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    }
    case 824:  // srawix
    {
      const u32 amount = inst.SH;
      const s32 rrs = s32(ppc_state.gpr[inst.RS]);
      ppc_state.gpr[inst.RA] = u32(rrs >> amount);
      ppc_state.SetCarry(rrs < 0 && amount > 0 && (u32(rrs) << (32 - amount)) != 0);
      if (inst.Rc)
        UpdateCR0(ppc_state, ppc_state.gpr[inst.RA]);
      return true;
    }
    case 75:  // mulhwux
    {
      const u64 a = ppc_state.gpr[inst.RA];
      const u64 b = ppc_state.gpr[inst.RB];
      const u32 d = static_cast<u32>((a * b) >> 32);
      ppc_state.gpr[inst.RD] = d;
      if (inst.Rc)
        UpdateCR0(ppc_state, d);
      return true;
    }
    case 83:  // mfmsr
      if (ppc_state.msr.PR)
        return false;
      ppc_state.gpr[inst.RD] = ppc_state.msr.Hex;
      return true;
    // Indexed load/store
    case 23:  // lwzx
    {
      u32 temp;
      if (TryFastmemReadU32(ea_x, temp))
      {
        ppc_state.gpr[inst.RD] = temp;
        return true;
      }
      temp = m_mmu.Read_U32(ea_x);
      if (!(ppc_state.Exceptions & EXCEPTION_DSI))
        ppc_state.gpr[inst.RD] = temp;
      return true;
    }
    case 87:  // lbzx
    {
      u32 temp;
      if (TryFastmemReadU8(ea_x, temp))
      {
        ppc_state.gpr[inst.RD] = temp;
        return true;
      }
      temp = m_mmu.Read_U8(ea_x);
      if (!(ppc_state.Exceptions & EXCEPTION_DSI))
        ppc_state.gpr[inst.RD] = temp;
      return true;
    }
    case 279:  // lhzx
    {
      u32 temp;
      if (TryFastmemReadU16(ea_x, temp))
      {
        ppc_state.gpr[inst.RD] = temp;
        return true;
      }
      temp = m_mmu.Read_U16(ea_x);
      if (!(ppc_state.Exceptions & EXCEPTION_DSI))
        ppc_state.gpr[inst.RD] = temp;
      return true;
    }
    case 151:  // stwx
    {
      const u32 value = ppc_state.gpr[inst.RS];
      if (TryFastmemWriteU32(ea_x, value))
        return true;
      m_mmu.Write_U32(value, ea_x);
      return true;
    }
    case 215:  // stbx
    {
      const u8 value = static_cast<u8>(ppc_state.gpr[inst.RS]);
      if (TryFastmemWriteU8(ea_x, value))
        return true;
      m_mmu.Write_U8(value, ea_x);
      return true;
    }
    case 407:  // sthx
    {
      const u16 value = static_cast<u16>(ppc_state.gpr[inst.RS]);
      if (TryFastmemWriteU16(ea_x, value))
        return true;
      m_mmu.Write_U16(value, ea_x);
      return true;
    }
    default:
      return false;
    }
  }

  case 16:  // bcx
  {
    if ((inst.BO & BO_DONT_DECREMENT_FLAG) == 0)
      CTR(ppc_state)--;

    const bool true_false = ((inst.BO >> 3) & 1) != 0;
    const bool only_counter_check = ((inst.BO >> 4) & 1) != 0;
    const bool only_condition_check = ((inst.BO >> 2) & 1) != 0;
    const u32 ctr_check = ((CTR(ppc_state) != 0) ^ (inst.BO >> 1)) & 1;
    const bool counter = only_condition_check || ctr_check != 0;
    const bool condition = only_counter_check || (ppc_state.cr.GetBit(inst.BI) == u32(true_false));

    if (counter && condition)
    {
      if (inst.LK)
        LR(ppc_state) = ppc_state.pc + 4;
      u32 destination_addr = u32(SignExt16(s16(inst.BD << 2)));
      if (!inst.AA)
        destination_addr += ppc_state.pc;
      ppc_state.npc = destination_addr;
    }
    return true;
  }

  case 18:  // bx
  {
    if (inst.LK)
      LR(ppc_state) = ppc_state.pc + 4;
    u32 destination_addr = u32(SignExt26(inst.LI << 2));
    if (!inst.AA)
      destination_addr += ppc_state.pc;
    ppc_state.npc = destination_addr;
    return true;
  }

  case 19:  // bclrx / bcctrx
  {
    const u32 subop = inst.SUBOP10;
    if (subop == 16)  // bclrx
    {
      if ((inst.BO_2 & BO_DONT_DECREMENT_FLAG) == 0)
        CTR(ppc_state)--;

      const u32 counter = ((inst.BO_2 >> 2) | ((CTR(ppc_state) != 0) ^ (inst.BO_2 >> 1))) & 1;
      const u32 condition =
          ((inst.BO_2 >> 4) | (ppc_state.cr.GetBit(inst.BI_2) == ((inst.BO_2 >> 3) & 1))) & 1;

      if ((counter & condition) != 0)
      {
        ppc_state.npc = LR(ppc_state) & (~3);
        if (inst.LK_3)
          LR(ppc_state) = ppc_state.pc + 4;
      }
      return true;
    }
    if (subop == 528)  // bcctrx
    {
      const u32 condition =
          ((inst.BO_2 >> 4) | (ppc_state.cr.GetBit(inst.BI_2) == ((inst.BO_2 >> 3) & 1))) & 1;
      if (condition != 0)
      {
        ppc_state.npc = CTR(ppc_state) & (~3);
        if (inst.LK_3)
          LR(ppc_state) = ppc_state.pc + 4;
      }
      return true;
    }
    return false;
  }

  case 24:  // ori
  {
    const u32 result = ppc_state.gpr[inst.RS] | inst.UIMM;
    ppc_state.gpr[inst.RA] = result;
    return true;
  }

  case 25:  // oris
  {
    const u32 result = ppc_state.gpr[inst.RS] | (u32(inst.UIMM) << 16);
    ppc_state.gpr[inst.RA] = result;
    return true;
  }

  case 26:  // xori
  {
    const u32 result = ppc_state.gpr[inst.RS] ^ inst.UIMM;
    ppc_state.gpr[inst.RA] = result;
    return true;
  }

  case 27:  // xoris
  {
    const u32 result = ppc_state.gpr[inst.RS] ^ (u32(inst.UIMM) << 16);
    ppc_state.gpr[inst.RA] = result;
    return true;
  }

  case 28:  // andi_rc
  {
    const u32 result = ppc_state.gpr[inst.RS] & inst.UIMM;
    ppc_state.gpr[inst.RA] = result;
    UpdateCR0(ppc_state, result);
    return true;
  }

  case 29:  // andis_rc
  {
    const u32 result = ppc_state.gpr[inst.RS] & (u32(inst.UIMM) << 16);
      ppc_state.gpr[inst.RA] = result;
    UpdateCR0(ppc_state, result);
    return true;
  }

  case 4:  // PS group
  {
    const u32 op5 = inst.SUBOP5;
    const auto& a = ppc_state.ps[inst.FA];
    const auto& b = ppc_state.ps[inst.FB];
    const auto& c = ppc_state.ps[inst.FC];

    float ps0, ps1;

    switch (op5)
    {
    case 29: // ps_madd
      ps0 = ForceSingle(
          ppc_state.fpscr,
          NI_madd<true>(ppc_state, a.PS0AsDouble(), c.PS0AsDouble(), b.PS0AsDouble()).value);
      ps1 = ForceSingle(
          ppc_state.fpscr,
          NI_madd<true>(ppc_state, a.PS1AsDouble(), c.PS1AsDouble(), b.PS1AsDouble()).value);
      break;
    
    case 14: // ps_madds0
      ps0 = ForceSingle(
          ppc_state.fpscr,
          NI_madd<true>(ppc_state, a.PS0AsDouble(), c.PS0AsDouble(), b.PS0AsDouble()).value);
      ps1 = ForceSingle(
          ppc_state.fpscr,
          NI_madd<true>(ppc_state, a.PS1AsDouble(), c.PS0AsDouble(), b.PS1AsDouble()).value);
      break;

    case 15: // ps_madds1
      ps0 = ForceSingle(
          ppc_state.fpscr,
          NI_madd<true>(ppc_state, a.PS0AsDouble(), c.PS1AsDouble(), b.PS0AsDouble()).value);
      ps1 = ForceSingle(
          ppc_state.fpscr,
          NI_madd<true>(ppc_state, a.PS1AsDouble(), c.PS1AsDouble(), b.PS1AsDouble()).value);
      break;

    case 12: // ps_muls0
      {
        const double c0 = Force25Bit(c.PS0AsDouble());
        ps0 = ForceSingle(ppc_state.fpscr, NI_mul(ppc_state, a.PS0AsDouble(), c0).value);
        ps1 = ForceSingle(ppc_state.fpscr, NI_mul(ppc_state, a.PS1AsDouble(), c0).value);
      }
      break;

    case 13: // ps_muls1
      {
        const double c1 = Force25Bit(c.PS1AsDouble());
        ps0 = ForceSingle(ppc_state.fpscr, NI_mul(ppc_state, a.PS0AsDouble(), c1).value);
        ps1 = ForceSingle(ppc_state.fpscr, NI_mul(ppc_state, a.PS1AsDouble(), c1).value);
      }
      break;

    default:
      return false;
    }

    ppc_state.ps[inst.FD].SetBoth(ps0, ps1);
    ppc_state.UpdateFPRFSingle(ps0);

    if (inst.Rc)
      ppc_state.UpdateCR1();

    return true;
  }

  // Load/Store instructions optimized with Fastmem
  case 37:  // stwu
  {
    const u32 value = ppc_state.gpr[inst.RS];
    if (TryFastmemWriteU32(address, value))
    {
       if (!(ppc_state.Exceptions & EXCEPTION_DSI))
         ppc_state.gpr[inst.RA] = address;
       return true;
    }
    m_mmu.Write_U32(value, address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      ppc_state.gpr[inst.RA] = address;
    return true;
  }

  case 32:  // lwz
  {
    u32 temp;
    if (TryFastmemReadU32(address, temp))
    {
       ppc_state.gpr[inst.RD] = temp;
       return true;
    }
    temp = m_mmu.Read_U32(address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      ppc_state.gpr[inst.RD] = temp;
    return true;
  }

  case 33:  // lwzu
  {
    u32 temp;
    if (TryFastmemReadU32(address, temp))
    {
      ppc_state.gpr[inst.RD] = temp;
      ppc_state.gpr[inst.RA] = address;
      return true;
    }
    temp = m_mmu.Read_U32(address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
    {
      ppc_state.gpr[inst.RD] = temp;
      ppc_state.gpr[inst.RA] = address;
    }
    return true;
  }

  case 34:  // lbz
  {
    u32 temp;
    if (TryFastmemReadU8(address, temp))
    {
       ppc_state.gpr[inst.RD] = temp;
       return true;
    }
    temp = m_mmu.Read_U8(address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      ppc_state.gpr[inst.RD] = temp;
    return true;
  }

  case 35:  // lbzu
  {
    u32 temp;
    if (TryFastmemReadU8(address, temp))
    {
      ppc_state.gpr[inst.RD] = temp;
      ppc_state.gpr[inst.RA] = address;
      return true;
    }
    temp = m_mmu.Read_U8(address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
    {
      ppc_state.gpr[inst.RD] = temp;
      ppc_state.gpr[inst.RA] = address;
    }
    return true;
  }

  case 36:  // stw
  {
    const u32 value = ppc_state.gpr[inst.RS];
    if (TryFastmemWriteU32(address, value))
        return true;
    m_mmu.Write_U32(value, address);
    return true;
  }

  case 38:  // stb
  {
    const u8 value = static_cast<u8>(ppc_state.gpr[inst.RS]);
    if (TryFastmemWriteU8(address, value))
        return true;
    m_mmu.Write_U8(value, address);
    return true;
  }

  case 39:  // stbu
  {
    const u8 value = static_cast<u8>(ppc_state.gpr[inst.RS]);
    if (TryFastmemWriteU8(address, value))
    {
      ppc_state.gpr[inst.RA] = address;
      return true;
    }
    m_mmu.Write_U8(value, address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      ppc_state.gpr[inst.RA] = address;
    return true;
  }

  case 40:  // lhz
  {
    u32 temp;
    if (TryFastmemReadU16(address, temp))
    {
       ppc_state.gpr[inst.RD] = temp;
       return true;
    }
    temp = m_mmu.Read_U16(address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      ppc_state.gpr[inst.RD] = temp;
    return true;
  }

  case 41:  // lhzu
  {
    u32 temp;
    if (TryFastmemReadU16(address, temp))
    {
      ppc_state.gpr[inst.RD] = temp;
      ppc_state.gpr[inst.RA] = address;
      return true;
    }
    temp = m_mmu.Read_U16(address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
    {
      ppc_state.gpr[inst.RD] = temp;
      ppc_state.gpr[inst.RA] = address;
    }
    return true;
  }

  case 44:  // sth
  {
    const u16 value = static_cast<u16>(ppc_state.gpr[inst.RS]);
    if (TryFastmemWriteU16(address, value))
        return true;
    m_mmu.Write_U16(value, address);
    return true;
  }

  case 45:  // sthu
  {
    const u16 value = static_cast<u16>(ppc_state.gpr[inst.RS]);
    if (TryFastmemWriteU16(address, value))
    {
      ppc_state.gpr[inst.RA] = address;
      return true;
    }
    m_mmu.Write_U16(value, address);
    if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      ppc_state.gpr[inst.RA] = address;
    return true;
  }

  case 48:  // lfs
    if ((address & 0b11) != 0)
    {
      GenerateAlignmentException(ppc_state, address);
      return true;
    }
    {
      u32 temp;
      if (TryFastmemReadU32(address, temp))
      {
        const u64 value = ConvertToDouble(temp);
        ppc_state.ps[inst.FD].Fill(value);
        return true;
      }
      temp = m_mmu.Read_U32(address);
      if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      {
        const u64 value = ConvertToDouble(temp);
        ppc_state.ps[inst.FD].Fill(value);
      }
    }
    return true;

  case 52:  // stfs
    if ((address & 0b11) != 0)
    {
      GenerateAlignmentException(ppc_state, address);
      return true;
    }
    {
      const u32 temp = ConvertToSingle(ppc_state.ps[inst.FS].PS0AsU64());
      if (TryFastmemWriteU32(address, temp))
          return true;
      m_mmu.Write_U32(temp, address);
    }
    return true;

  case 50:  // lfd
    if ((address & 0b11) != 0)
    {
      GenerateAlignmentException(ppc_state, address);
      return true;
    }
    {
      u64 temp;
      if (TryFastmemReadU64(address, temp))
      {
        ppc_state.ps[inst.FD].SetPS0(temp);
        return true;
      }
      temp = m_mmu.Read_U64(address);
      if (!(ppc_state.Exceptions & EXCEPTION_DSI))
        ppc_state.ps[inst.FD].SetPS0(temp);
    }
    return true;

  case 51:  // lfdu
    if ((address & 0b11) != 0)
    {
      GenerateAlignmentException(ppc_state, address);
      return true;
    }
    {
      u64 temp;
      if (TryFastmemReadU64(address, temp))
      {
         ppc_state.ps[inst.FD].SetPS0(temp);
         ppc_state.gpr[inst.RA] = address;
         return true;
      }
      temp = m_mmu.Read_U64(address);
      if (!(ppc_state.Exceptions & EXCEPTION_DSI))
      {
        ppc_state.ps[inst.FD].SetPS0(temp);
        ppc_state.gpr[inst.RA] = address;
      }
    }
    return true;

  case 54:  // stfd
    if ((address & 0b11) != 0)
    {
      GenerateAlignmentException(ppc_state, address);
      return true;
    }
    {
      const u64 value = ppc_state.ps[inst.FS].PS0AsU64();
      if (TryFastmemWriteU64(address, value))
          return true;
      m_mmu.Write_U64(value, address);
    }
    return true;

  case 55:  // stfdu
    if ((address & 0b11) != 0)
    {
      GenerateAlignmentException(ppc_state, address);
      return true;
    }
    {
      const u64 temp = ppc_state.ps[inst.FS].PS0AsU64();
      if (TryFastmemWriteU64(address, temp))
      {
        if (!(ppc_state.Exceptions & EXCEPTION_DSI))
          ppc_state.gpr[inst.RA] = address;
        return true;
      }
      m_mmu.Write_U64(temp, address);
      if (!(ppc_state.Exceptions & EXCEPTION_DSI))
        ppc_state.gpr[inst.RA] = address;
    }
    return true;

  default:
    return false;
  }
}
void CachedInterpreter::ExecuteOneBlock()
{
  const u8* normal_entry = m_block_cache.Dispatch();
  if (!normal_entry)
  {
    Jit(m_ppc_state.pc);
    return;
  }
  // Defensive check: ensure the pointer is within our allocated code region to avoid
  // use-after-free or stale pointers (e.g. block invalidated while still referenced).
  if (!IsInSpace(normal_entry))
  {
    Jit(m_ppc_state.pc);
    return;
  }

  auto& ppc_state = m_ppc_state;
  while (true)
  {
    const auto callback = *reinterpret_cast<const AnyCallback*>(normal_entry);
    const u8* payload = normal_entry + sizeof(callback);
    // Direct dispatch to the most commonly used callbacks for better performance
    if (callback == reinterpret_cast<AnyCallback>(CallbackCast(Interpret<false>))) [[likely]]
    {
      const auto& operands = *reinterpret_cast<const InterpretOperands*>(payload);
      if (!TryInlineHotInstruction(false, operands))
        Interpret<false>(ppc_state, operands);
      normal_entry = payload + sizeof(InterpretOperands);
    }
    else if (callback == reinterpret_cast<AnyCallback>(CallbackCast(Interpret<true>)))
    {
      const auto& operands = *reinterpret_cast<const InterpretOperands*>(payload);
      if (!TryInlineHotInstruction(true, operands))
        Interpret<true>(ppc_state, operands);
      normal_entry = payload + sizeof(InterpretOperands);
    }
    else
    {
      if (const auto distance = callback(ppc_state, payload))
        normal_entry += distance;
      else
        break;
    }
  }
}




void CachedInterpreter::Run()
{
  auto& core_timing = m_system.GetCoreTiming();

  const CPU::State* state_ptr = m_system.GetCPU().GetStatePtr();
  while (*state_ptr == CPU::State::Running)
  {
    // Start new timing slice
    // NOTE: Exceptions may change PC
    core_timing.Advance();

    do
    {
      ExecuteOneBlock();
    } while (m_ppc_state.downcount > 0 && *state_ptr == CPU::State::Running);
  }
}

void CachedInterpreter::SingleStep()
{
  // Enter new timing slice
  m_system.GetCoreTiming().Advance();
  ExecuteOneBlock();
}

s32 CachedInterpreter::StartProfiledBlock(PowerPC::PowerPCState& ppc_state,
                                          const StartProfiledBlockOperands& operands)
{
  JitBlock::ProfileData::BeginProfiling(operands.profile_data);
  return sizeof(AnyCallback) + sizeof(operands);
}

template <bool profiled>
s32 CachedInterpreter::EndBlock(PowerPC::PowerPCState& ppc_state,
                                const EndBlockOperands<profiled>& operands)
{
  ppc_state.pc = ppc_state.npc;
  ppc_state.downcount -= operands.downcount;
  if ((ppc_state.feature_flags & FEATURE_FLAG_PERFMON) != 0)
  {
    PowerPC::UpdatePerformanceMonitor(operands.downcount, operands.num_load_stores,
                                      operands.num_fp_inst, ppc_state);
  }
  if constexpr (profiled)
    JitBlock::ProfileData::EndProfiling(operands.profile_data, operands.downcount);

  if (!operands.block_cache)
    return 0;

  if (ppc_state.downcount <= 0)
    return 0;

  if (!operands.cpu_state_ptr || *operands.cpu_state_ptr != CPU::State::Running)
    return 0;

  const u32 npc = ppc_state.npc;
  const u64 generation = operands.block_cache->GetGeneration();
  if (operands.cached_entry && operands.cached_generation == generation &&
      operands.cached_npc == npc)
  {
    const auto current_entry =
        reinterpret_cast<const u8*>(&operands) - sizeof(AnyCallback);
    return static_cast<s32>(operands.cached_entry - current_entry);
  }

  operands.cached_generation = generation;
  operands.cached_npc = npc;
  if (JitBlock* const next_block =
          operands.block_cache->GetBlockFromStartAddress(npc, ppc_state.feature_flags))
  {
    operands.cached_entry = next_block->normalEntry;
    const auto current_entry =
        reinterpret_cast<const u8*>(&operands) - sizeof(AnyCallback);
    return static_cast<s32>(operands.cached_entry - current_entry);
  }

  operands.cached_entry = nullptr;
  return 0;
}

template <bool write_pc>
s32 CachedInterpreter::Interpret(PowerPC::PowerPCState& ppc_state,
                                 const InterpretOperands& operands)
{
  if constexpr (write_pc)
  {
    ppc_state.pc = operands.current_pc;
    ppc_state.npc = operands.current_pc + 4;
  }
  operands.func(operands.interpreter, operands.inst);
  return sizeof(AnyCallback) + sizeof(operands);
}

template <bool write_pc>
s32 CachedInterpreter::InterpretAndCheckExceptions(
    PowerPC::PowerPCState& ppc_state, const InterpretAndCheckExceptionsOperands& operands)
{
  if constexpr (write_pc)
  {
    ppc_state.pc = operands.current_pc;
    ppc_state.npc = operands.current_pc + 4;
  }
  operands.func(operands.interpreter, operands.inst);

  if ((ppc_state.Exceptions & (EXCEPTION_DSI | EXCEPTION_PROGRAM)) != 0)
  {
    ppc_state.pc = operands.current_pc;
    ppc_state.downcount -= operands.downcount;
    operands.power_pc.CheckExceptions();
    return 0;
  }
  return sizeof(AnyCallback) + sizeof(operands);
}

s32 CachedInterpreter::HLEFunction(PowerPC::PowerPCState& ppc_state,
                                   const HLEFunctionOperands& operands)
{
  const auto& [system, current_pc, hook_index] = operands;
  ppc_state.pc = current_pc;
  HLE::Execute(Core::CPUThreadGuard{system}, current_pc, hook_index);
  return sizeof(AnyCallback) + sizeof(operands);
}

s32 CachedInterpreter::WriteBrokenBlockNPC(PowerPC::PowerPCState& ppc_state,
                                           const WriteBrokenBlockNPCOperands& operands)
{
  const auto& [current_pc] = operands;
  ppc_state.npc = current_pc;
  return sizeof(AnyCallback) + sizeof(operands);
}

s32 CachedInterpreter::InlineCmpBc(PowerPC::PowerPCState& ppc_state,
                                   const InlineCmpBcOperands& operands)
{
  const auto& [branch_watch, cmp_func, cmp_inst, bc_inst, cmp_pc] = operands;

  ppc_state.pc = cmp_pc;
  ppc_state.npc = cmp_pc + 4;

  const bool cmp_immediate = (cmp_func == &Interpreter::cmpi || cmp_func == &Interpreter::cmpli);
  const bool cmp_signed = (cmp_func == &Interpreter::cmpi || cmp_func == &Interpreter::cmp);
  u32 cr_field;

  if (cmp_signed)
  {
    const s32 a = static_cast<s32>(ppc_state.gpr[cmp_inst.RA]);
    const s32 b =
        cmp_immediate ? static_cast<s32>(cmp_inst.SIMM_16) : static_cast<s32>(ppc_state.gpr[cmp_inst.RB]);
    if (a < b)
      cr_field = PowerPC::CR_LT;
    else if (a > b)
      cr_field = PowerPC::CR_GT;
    else
      cr_field = PowerPC::CR_EQ;
  }
  else
  {
    const u32 a = ppc_state.gpr[cmp_inst.RA];
    const u32 b = cmp_immediate ? cmp_inst.UIMM : ppc_state.gpr[cmp_inst.RB];
    if (a < b)
      cr_field = PowerPC::CR_LT;
    else if (a > b)
      cr_field = PowerPC::CR_GT;
    else
      cr_field = PowerPC::CR_EQ;
  }

  if (ppc_state.GetXER_SO())
    cr_field |= PowerPC::CR_SO;
  ppc_state.cr.fields[cmp_inst.CRFD] = PowerPC::ConditionRegister::s_crTable[cr_field];

  const u32 bc_pc = cmp_pc + 4;
  ppc_state.pc = bc_pc;
  ppc_state.npc = bc_pc + 4;

  if ((bc_inst.BO & BO_DONT_DECREMENT_FLAG) == 0)
    CTR(ppc_state)--;

  const bool true_false = ((bc_inst.BO >> 3) & 1) != 0;
  const bool only_counter_check = ((bc_inst.BO >> 4) & 1) != 0;
  const bool only_condition_check = ((bc_inst.BO >> 2) & 1) != 0;
  const u32 ctr_check = ((CTR(ppc_state) != 0) ^ (bc_inst.BO >> 1)) & 1;
  const bool counter = only_condition_check || ctr_check != 0;
  const bool condition =
      only_counter_check || (FastCRBit(ppc_state, bc_inst.BI) == u32(true_false));

  if (counter && condition)
  {
    if (bc_inst.LK)
      LR(ppc_state) = ppc_state.pc + 4;

    u32 destination_addr = u32(SignExt16(s16(bc_inst.BD << 2)));
    if (!bc_inst.AA)
      destination_addr += ppc_state.pc;
    ppc_state.npc = destination_addr;

    if (branch_watch.GetRecordingActive())
      branch_watch.HitTrue(ppc_state.pc, destination_addr, bc_inst, ppc_state.msr.IR);
  }
  else if (branch_watch.GetRecordingActive())
  {
    branch_watch.HitFalse(ppc_state.pc, ppc_state.pc + 4, bc_inst, ppc_state.msr.IR);
  }

  return sizeof(AnyCallback) + sizeof(operands);
}

s32 CachedInterpreter::CheckFPU(PowerPC::PowerPCState& ppc_state, const CheckHaltOperands& operands)
{
  const auto& [power_pc, current_pc, downcount] = operands;
  if (!ppc_state.msr.FP)
  {
    ppc_state.pc = current_pc;
    ppc_state.downcount -= downcount;
    ppc_state.Exceptions |= EXCEPTION_FPU_UNAVAILABLE;
    power_pc.CheckExceptions();
    return 0;
  }
  return sizeof(AnyCallback) + sizeof(operands);
}

s32 CachedInterpreter::CheckBreakpoint(PowerPC::PowerPCState& ppc_state,
                                       const CheckHaltOperands& operands)
{
  const auto& [power_pc, current_pc, downcount] = operands;
  ppc_state.pc = current_pc;
  if (power_pc.CheckAndHandleBreakPoints())
  {
    // Accessing PowerPCState through power_pc instead of ppc_state produces better assembly.
    power_pc.GetPPCState().downcount -= downcount;
    return 0;
  }
  return sizeof(AnyCallback) + sizeof(operands);
}

s32 CachedInterpreter::CheckIdle(PowerPC::PowerPCState& ppc_state,
                                 const CheckIdleOperands& operands)
{
  const auto& [core_timing, idle_pc] = operands;
  if (ppc_state.npc == idle_pc)
    core_timing.Idle();
  return sizeof(AnyCallback) + sizeof(operands);
}

bool CachedInterpreter::HandleFunctionHooking(u32 address)
{
  // CachedInterpreter inherits from JitBase and is considered a JIT by relevant code.
  // (see JitInterface and how m_mode is set within PowerPC.cpp)
  const auto result = HLE::TryReplaceFunction(m_ppc_symbol_db, address, PowerPC::CoreMode::JIT);
  if (!result)
    return false;

  Write(HLEFunction, {m_system, address, result.hook_index});

  if (result.type != HLE::HookType::Replace)
    return false;

  js.downcountAmount += js.st.numCycles;
  WriteEndBlock();
  return true;
}

void CachedInterpreter::WriteEndBlock()
{
  if (IsProfilingEnabled())
  {
    const EndBlockOperands<true> operands = {
        &m_block_cache,
        m_system.GetCPU().GetStatePtr(),
        nullptr,
        0,
        0,
        js.downcountAmount,
        js.numLoadStoreInst,
        js.numFloatingPointInst,
        js.curBlock->profile_data.get()};
    Write(EndBlock<true>, operands);
  }
  else
  {
    const EndBlockOperands<false> operands = {
        &m_block_cache, m_system.GetCPU().GetStatePtr(), nullptr, 0, 0, js.downcountAmount,
        js.numLoadStoreInst, js.numFloatingPointInst};
    Write(EndBlock<false>, operands);
  }
}

bool CachedInterpreter::SetEmitterStateToFreeCodeRegion()
{
  const auto free = m_free_ranges.by_size_begin();
  if (free == m_free_ranges.by_size_end())
  {
    WARN_LOG_FMT(DYNA_REC, "Failed to find free memory region in code region.");
    return false;
  }
  SetCodePtr(free.from(), free.to());
  return true;
}

void CachedInterpreter::FreeRanges()
{
  for (const auto& [from, to] : m_block_cache.GetRangesToFree())
    m_free_ranges.insert(from, to);
  m_block_cache.ClearRangesToFree();
}

void CachedInterpreter::ResetFreeMemoryRanges()
{
  m_free_ranges.clear();
  m_free_ranges.insert(region, region + region_size);
}

void CachedInterpreter::Jit(u32 em_address)
{
  Jit(em_address, true);
}

void CachedInterpreter::Jit(u32 em_address, bool clear_cache_and_retry_on_failure)
{
  if (IsAlmostFull() || SConfig::GetInstance().bJITNoBlockCache)
  {
    ClearCache();
  }
  FreeRanges();

  const u32 nextPC =
      analyzer.Analyze(em_address, &code_block, &m_code_buffer, m_code_buffer.size());
  if (code_block.m_memory_exception)
  {
    // Address of instruction could not be translated
    m_ppc_state.npc = nextPC;
    m_ppc_state.Exceptions |= EXCEPTION_ISI;
    m_system.GetPowerPC().CheckExceptions();
    WARN_LOG_FMT(POWERPC, "ISI exception at {:#010x}", nextPC);
    return;
  }

  if (SetEmitterStateToFreeCodeRegion())
  {
    JitBlock* b = m_block_cache.AllocateBlock(em_address);
    b->normalEntry = b->near_begin = GetWritableCodePtr();

    if (DoJit(em_address, b, nextPC))
    {
      // Record what memory region was used so we know what to free if this block gets invalidated.
      b->near_end = GetWritableCodePtr();
      b->far_begin = b->far_end = nullptr;

      // Mark the memory region that this code block uses in the RangeSizeSet.
      if (b->near_begin != b->near_end)
        m_free_ranges.erase(b->near_begin, b->near_end);

      m_block_cache.FinalizeBlock(*b, jo.enableBlocklink, code_block, m_code_buffer);

#ifdef JIT_LOG_GENERATED_CODE
      LogGeneratedCode();
#endif

      return;
    }
  }

  if (clear_cache_and_retry_on_failure)
  {
    WARN_LOG_FMT(DYNA_REC, "flushing code caches, please report if this happens a lot");
    ClearCache();
    Jit(em_address, false);
    return;
  }

  PanicAlertFmtT("JIT failed to find code space after a cache clear. This should never happen. "
                 "Please report this incident on the bug tracker. Dolphin will now exit.");
  std::exit(-1);
}

bool CachedInterpreter::DoJit(u32 em_address, JitBlock* b, u32 nextPC)
{
  js.blockStart = em_address;
  js.firstFPInstructionFound = false;
  js.fifoBytesSinceCheck = 0;
  js.downcountAmount = 0;
  js.numLoadStoreInst = 0;
  js.numFloatingPointInst = 0;
  js.curBlock = b;

  auto& interpreter = m_system.GetInterpreter();
  auto& power_pc = m_system.GetPowerPC();
  auto& cpu = m_system.GetCPU();
  auto& breakpoints = power_pc.GetBreakPoints();

  if (IsProfilingEnabled())
    Write(StartProfiledBlock, {js.curBlock->profile_data.get()});

  for (u32 i = 0; i < code_block.m_num_instructions; i++)
  {
    PPCAnalyst::CodeOp& op = m_code_buffer[i];
    js.op = &op;

    js.compilerPC = op.address;
    js.instructionsLeft = (code_block.m_num_instructions - 1) - i;
    js.downcountAmount += op.opinfo->num_cycles;
    if (op.opinfo->flags & FL_LOADSTORE)
      ++js.numLoadStoreInst;
    if (op.opinfo->flags & FL_USE_FPU)
      ++js.numFloatingPointInst;

    if (HandleFunctionHooking(js.compilerPC))
      break;

    if (!op.skip)
    {
      const auto op_func = Interpreter::GetInterpreterOp(op.inst);
      if (IsDebuggingEnabled() && !cpu.IsStepping() &&
          breakpoints.IsAddressBreakPoint(js.compilerPC))
      {
        Write(CheckBreakpoint, {power_pc, js.compilerPC, js.downcountAmount});
      }
      if (!js.firstFPInstructionFound && (op.opinfo->flags & FL_USE_FPU) != 0)
      {
        Write(CheckFPU, {power_pc, js.compilerPC, js.downcountAmount});
        js.firstFPInstructionFound = true;
      }

      // Instruction may cause a DSI Exception or Program Exception.
      if ((jo.memcheck && (op.opinfo->flags & FL_LOADSTORE) != 0) ||
          (!op.canEndBlock && ShouldHandleFPExceptionForInstruction(&op)))
      {
        const InterpretAndCheckExceptionsOperands operands = {
            {interpreter, op_func, js.compilerPC, op.inst},
            power_pc,
            js.downcountAmount};
        Write(op.canEndBlock ? CallbackCast(InterpretAndCheckExceptions<true>) :
                               CallbackCast(InterpretAndCheckExceptions<false>),
              operands);
      }
      else
      {
        const InterpretOperands operands = {interpreter, op_func, js.compilerPC, op.inst};
        Write(op.canEndBlock ? CallbackCast(Interpret<true>) : CallbackCast(Interpret<false>),
              operands);
      }

      if (op.branchIsIdleLoop)
        Write(CheckIdle, {m_system.GetCoreTiming(), js.blockStart});
      if (op.canEndBlock)
        WriteEndBlock();
    }
  }
  if (code_block.m_broken)
  {
    Write(WriteBrokenBlockNPC, {nextPC});
    WriteEndBlock();
  }

  if (HasWriteFailed())
  {
    WARN_LOG_FMT(DYNA_REC, "JIT ran out of space in code region during code generation.");
    return false;
  }
  return true;
}

void CachedInterpreter::EraseSingleBlock(const JitBlock& block)
{
  m_block_cache.EraseSingleBlock(block);
  FreeRanges();
}

std::vector<JitBase::MemoryStats> CachedInterpreter::GetMemoryStats() const
{
  return {{"free", m_free_ranges.get_stats()}};
}

std::size_t CachedInterpreter::DisassembleNearCode(const JitBlock& block,
                                                   std::ostream& stream) const
{
  return Disassemble(block, stream);
}

std::size_t CachedInterpreter::DisassembleFarCode(const JitBlock& block, std::ostream& stream) const
{
  stream << "N/A\n";
  return 0;
}

void CachedInterpreter::ClearCache()
{
  m_block_cache.Clear();
  m_block_cache.ClearRangesToFree();
  m_block_cache.BumpGeneration();
  ClearCodeSpace();
  ResetFreeMemoryRanges();
  RefreshConfig();
  ResetFastmemCache();
  Host_JitCacheInvalidation();
}

void CachedInterpreter::LogGeneratedCode() const
{
  std::ostringstream stream;

  stream << "\nPPC Code Buffer:\n";
  for (const PPCAnalyst::CodeOp& op :
       std::span{m_code_buffer.data(), code_block.m_num_instructions})
  {
    fmt::print(stream, "0x{:08x}\t\t{}\n", op.address,
               Common::GekkoDisassembler::Disassemble(op.inst.hex, op.address));
  }

  stream << "\nHost Code:\n";
  Disassemble(*js.curBlock, stream);

  // TODO C++20: std::ostringstream::view()
  DEBUG_LOG_FMT(DYNA_REC, "{}", std::move(stream).str());
}
