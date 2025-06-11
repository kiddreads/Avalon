using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostCtrl.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct SyncptWaitExArguments
    {
        public SyncptWaitArguments Input;
        public uint Value;
    }
}
