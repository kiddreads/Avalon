using Ryujinx.Common.Utilities;
using System.Runtime.InteropServices;

namespace Ryujinx.Graphics.Vic.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    readonly struct PipeConfig
    {
        private readonly long _word0;
        private readonly long _word1;

        public int DownsampleHoriz => (int)_word0.Extract(0, 11);
        public int DownsampleVert => (int)_word0.Extract(16, 11);
    }
}
