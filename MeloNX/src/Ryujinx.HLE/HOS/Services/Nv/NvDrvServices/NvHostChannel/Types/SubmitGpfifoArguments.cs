using Ryujinx.HLE.HOS.Services.Nv.Types;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostChannel.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct SubmitGpfifoArguments
    {
        public long Address;
        public int NumEntries;
        public SubmitGpfifoFlags Flags;
        public NvFence Fence;
    }
}
