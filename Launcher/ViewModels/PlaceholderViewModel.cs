using CommunityToolkit.Mvvm.ComponentModel;

namespace Amiin.ViewModels;

/// <summary>Shared model for sidebar destinations that don't have a dedicated screen or a
/// backing API yet (Store, Friends) -- an honest "not built yet" page instead of the sidebar
/// link silently doing nothing when clicked.</summary>
public partial class PlaceholderViewModel : ObservableObject
{
    [ObservableProperty] private string title = "";
    [ObservableProperty] private string message = "";

    public PlaceholderViewModel(string title, string message)
    {
        Title = title; Message = message;
    }
}
