using Ryujinx.Graphics.Gpu.Engine.Types;

namespace Ryujinx.Graphics.Gpu.Engine.Twod
{
    /// <summary>
    /// Texture to texture (with optional resizing) copy parameters.
    /// </summary>
    struct TwodTexture
    {

        public ColorFormat Format;
        public Boolean32 LinearLayout;
        public MemoryLayout MemoryLayout;
        public int Depth;
        public int Layer;
        public int Stride;
        public int Width;
        public int Height;
        public GpuVa Address;

    }
}
