using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvMap
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct NvMapParam
    {
        public int Handle;
        public NvMapHandleParam Param;
        public int Result;
    }
}
