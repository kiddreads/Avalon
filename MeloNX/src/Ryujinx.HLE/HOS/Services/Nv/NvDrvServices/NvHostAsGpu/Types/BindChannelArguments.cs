using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostAsGpu.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct BindChannelArguments
    {
        public int Fd;
    }
}
