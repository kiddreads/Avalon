using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostChannel.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct ZcullBindArguments
    {
        public ulong GpuVirtualAddress;
        public uint Mode;
        public uint Reserved;
    }
}
