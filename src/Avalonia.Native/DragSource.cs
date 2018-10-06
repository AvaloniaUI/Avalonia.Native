using System;
using System.Threading.Tasks;
using Avalonia.Input;
using Avalonia.Input.Platform;
using Avalonia.Native.Interop;

namespace Avalonia.Native
{
    public class DragSource : IPlatformDragSource
    {
        IAvnPlatformDragSource _native;

        public DragSource(IAvaloniaNativeFactory factory)
        {
            _native = factory.CreatePlatformDragSource();
        }

        public Task<DragDropEffects> DoDragDrop(IDataObject data, DragDropEffects allowedEffects)
        {
            return Task.FromResult<DragDropEffects>(DragDropEffects.None);
        }
    }
}
