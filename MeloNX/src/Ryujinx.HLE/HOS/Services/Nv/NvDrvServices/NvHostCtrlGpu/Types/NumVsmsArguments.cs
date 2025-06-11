using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostCtrlGpu.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct NumVsmsArguments
    {
        public uint NumVsms;
        public uint Reserved;
    }
}
