using System;

namespace Ryujinx.Cpu
{
    public class DummyDiskCacheLoadState : IDiskCacheLoadState
    {
        /// <inheritdoc/>
        public event Action<LoadState, int, int> StateChanged;

        public DummyDiskCacheLoadState() => StateChanged?.Invoke(LoadState.Unloaded, 0, 0);

        /// <inheritdoc/>
        public void Cancel()
        {
        }
    }
}
