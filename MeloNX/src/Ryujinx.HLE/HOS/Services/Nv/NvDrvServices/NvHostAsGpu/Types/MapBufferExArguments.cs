using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostAsGpu.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct MapBufferExArguments
    {
        public AddressSpaceFlags Flags;
        public int Kind;
        public int NvMapHandle;
        public int PageSize;
        public ulong BufferOffset;
        public ulong MappingSize;
        public ulong Offset;
    }
}
