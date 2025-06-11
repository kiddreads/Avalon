using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvMap
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct NvMapFromId
    {
        public int Id;
        public int Handle;
    }
}
