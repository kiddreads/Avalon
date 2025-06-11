using ARMeilleure.State;
using Ryujinx.Common.Memory;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Kernel.SupervisorCall
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct ThreadContext
    {
        public Array29<ulong> Registers;
        public ulong Fp;
        public ulong Lr;
        public ulong Sp;
        public ulong Pc;
        public uint Pstate;

        private readonly uint _padding;

        public Array32<V128> FpuRegisters;
        public uint Fpcr;
        public uint Fpsr;
        public ulong Tpidr;
    }
}
