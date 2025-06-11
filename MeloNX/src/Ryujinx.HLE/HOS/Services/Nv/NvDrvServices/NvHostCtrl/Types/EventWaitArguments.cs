using Ryujinx.HLE.HOS.Services.Nv.Types;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostCtrl.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct EventWaitArguments
    {
        public NvFence Fence;
        public int Timeout;
        public uint Value;
    }
}
