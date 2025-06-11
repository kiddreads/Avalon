using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Nv.NvDrvServices.NvHostChannel.Types
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct CommandBuffer
    {
        public int Mem;
        public uint Offset;
        public int WordsCount;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct Reloc
    {
        public int CmdbufMem;
        public int CmdbufOffset;
        public int Target;
        public int TargetOffset;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct SyncptIncr
    {
        public uint Id;
        public uint Incrs;
        public uint Reserved1;
        public uint Reserved2;
        public uint Reserved3;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct SubmitArguments
    {
        public int CmdBufsCount;
        public int RelocsCount;
        public int SyncptIncrsCount;
        public int FencesCount;
    }
}
