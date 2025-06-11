using ARMeilleure.Memory;
using System;

namespace Ryujinx.Tests.Memory
{
    internal class MockMemoryManager : IMemoryManager
    {
        public int AddressSpaceBits => throw new NotImplementedException();

        public nint PageTablePointer => throw new NotImplementedException();

        public MemoryManagerType Type => MemoryManagerType.HostMappedUnsafe;

        public event Action<ulong, ulong> UnmapEvent;

        public ref T GetRef<T>(ulong va) where T : unmanaged
        {
            throw new NotImplementedException();
        }

        public ReadOnlySpan<byte> GetSpan(ulong va, int size, bool tracked = false)
        {
            throw new NotImplementedException();
        }

        public bool IsMapped(ulong va)
        {
            throw new NotImplementedException();
        }

        public T Read<T>(ulong va) where T : unmanaged
        {
            throw new NotImplementedException();
        }

        public T ReadTracked<T>(ulong va) where T : unmanaged
        {
            throw new NotImplementedException();
        }

        public void SignalMemoryTracking(ulong va, ulong size, bool write, bool precise = false, int? exemptId = null)
        {
            throw new NotImplementedException();
        }

        public void Write<T>(ulong va, T value) where T : unmanaged
        {
            throw new NotImplementedException();
        }

        // Since the mock never unmaps memory, the UnmapEvent is never used and this causes a warning.
        // This method is provided to allow the mock to trigger the event if needed.
        public void Unmap(ulong va, ulong size)
        {
            UnmapEvent?.Invoke(va, size);
        }
    }
}
