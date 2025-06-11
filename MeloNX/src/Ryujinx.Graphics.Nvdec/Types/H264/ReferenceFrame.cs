using Ryujinx.Common.Memory;

namespace Ryujinx.Graphics.Nvdec.Types.H264
{
    struct ReferenceFrame
    {

        public uint Flags;
        public Array2<uint> FieldOrderCnt;
        public uint FrameNum;

        public readonly uint OutputSurfaceIndex => (uint)Flags & 0x7f;
    }
}
