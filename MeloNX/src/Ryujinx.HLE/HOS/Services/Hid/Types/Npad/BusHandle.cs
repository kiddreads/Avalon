using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Hid
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct BusHandle
    {
        public int AbstractedPadId;
        public byte InternalIndex;
        public byte PlayerNumber;
        public byte BusTypeId;
        public byte IsValid;
    }
}
