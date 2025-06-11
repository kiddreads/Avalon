using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostAsGpu.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct AllocSpaceArguments
    {
        public uint Pages;
        public uint PageSize;
        public AddressSpaceFlags Flags;
        public uint Padding;
        public ulong Offset;
    }
}
