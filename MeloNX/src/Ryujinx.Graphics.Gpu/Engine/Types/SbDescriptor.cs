namespace Ryujinx.Graphics.Gpu.Engine.Types
{
    /// <summary>
    /// Storage buffer address and size information.
    /// </summary>
    struct SbDescriptor
    {

        public uint AddressLow;
        public uint AddressHigh;
        public int Size;
        public int Padding;

        public readonly ulong PackAddress()
        {
            return AddressLow | ((ulong)AddressHigh << 32);
        }
    }
}
