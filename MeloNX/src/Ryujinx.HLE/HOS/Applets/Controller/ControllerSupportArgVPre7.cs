using Ryujinx.Common.Memory;
using System;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Applets
{

    // (1.0.0+ version)
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct ControllerSupportArgVPre7
    {
        public ControllerSupportArgHeader Header;
        public Array4<uint> IdentificationColor;
        public byte EnableExplainText;
        public ExplainTextStruct ExplainText;

        [StructLayout(LayoutKind.Sequential, Size = 4 * 0x81)]
        public struct ExplainTextStruct
        {
            private byte element;

            public Span<byte> AsSpan() => MemoryMarshal.CreateSpan(ref element, 4 * 0x81);
        }
    }
}
