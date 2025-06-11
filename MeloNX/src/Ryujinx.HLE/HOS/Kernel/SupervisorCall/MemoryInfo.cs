using Ryujinx.HLE.HOS.Kernel.Memory;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Kernel.SupervisorCall
{
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct MemoryInfo
    {
        public ulong Address;
        public ulong Size;
        public MemoryState State;
        public MemoryAttribute Attribute;
        public KMemoryPermission Permission;
        public int IpcRefCount;
        public int DeviceRefCount;
        private readonly int _padding;

        public MemoryInfo(
            ulong address,
            ulong size,
            MemoryState state,
            MemoryAttribute attribute,
            KMemoryPermission permission,
            int ipcRefCount,
            int deviceRefCount)
        {
            Address = address;
            Size = size;
            State = state;
            Attribute = attribute;
            Permission = permission;
            IpcRefCount = ipcRefCount;
            DeviceRefCount = deviceRefCount;
            _padding = 0;
        }
    }
}
