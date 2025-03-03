using Avalonia.Controls;
using Gommon;
using Ryujinx.Ava.UI.ViewModels;
using System;

namespace Ryujinx.Ava.UI.Controls
{
    public class RyujinxControl<TViewModel> : UserControl where TViewModel : BaseModel
    {
        public TViewModel ViewModel
        {
            get => (TViewModel)DataContext ?? throw new InvalidOperationException(
                $"Underlying DataContext is not of type {typeof(TViewModel).AsPrettyString()}; " +
                $"Actual type is {DataContext?.GetType().AsPrettyString()}");
            set => DataContext = value;
        }
    }
}
