using System;
using System.Runtime.InteropServices;

namespace Ryujinx.Graphics.Gpu.Engine
{
    /// <summary>
    /// Represents temporary storage used by macros.
    /// </summary>
    [StructLayout(LayoutKind.Sequential, Size = 1024)]
    struct MmeShadowScratch
    {
        private uint _e0;
        public ref uint this[int index] => ref AsSpan()[index];
        public Span<uint> AsSpan() => MemoryMarshal.CreateSpan(ref _e0, 256);
    }
}
