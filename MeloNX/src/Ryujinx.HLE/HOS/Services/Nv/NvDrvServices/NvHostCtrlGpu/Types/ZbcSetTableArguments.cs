using Ryujinx.Common.Memory;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostCtrlGpu.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct ZbcSetTableArguments
    {
        public Array4<uint> ColorDs;
        public Array4<uint> ColorL2;
        public uint Depth;
        public uint Format;
        public uint Type;
    }
}
