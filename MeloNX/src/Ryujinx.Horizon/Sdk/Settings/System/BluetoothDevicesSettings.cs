using Ryujinx.Common.Memory;

namespace Ryujinx.Horizon.Sdk.Settings.System
{
    struct BluetoothDevicesSettings
    {

        public Array6<byte> BdAddr;
        public Array32<byte> DeviceName;
        public Array3<byte> ClassOfDevice;
        public Array16<byte> LinkKey;
        public bool LinkKeyPresent;
        public ushort Version;
        public uint TrustedServices;
        public ushort Vid;
        public ushort Pid;
        public byte SubClass;
        public byte AttributeMask;
        public ushort DescriptorLength;
        public Array128<byte> Descriptor;
        public byte KeyType;
        public byte DeviceType;
        public ushort BrrSize;
        public Array9<byte> Brr;
        public Array256<byte> Reserved;
        public Array43<byte> Reserved2;

    }
}
