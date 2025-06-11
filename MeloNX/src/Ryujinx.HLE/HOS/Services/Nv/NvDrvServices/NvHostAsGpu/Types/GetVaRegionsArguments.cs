using Ryujinx.Common.Memory;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostAsGpu.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct VaRegion
    {
        public ulong Offset;
        public uint PageSize;
        public uint Padding;
        public ulong Pages;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct GetVaRegionsArguments
    {
        public ulong Unused;
        public uint BufferSize;
        public uint Padding;
        public Array2<VaRegion> Regions;
    }
}
