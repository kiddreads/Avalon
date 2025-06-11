using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvMap
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct NvMapAlloc
    {
        public int Handle;
        public int HeapMask;
        public int Flags;
        public int Align;
        public long Kind;
        public ulong Address;
    }
}
