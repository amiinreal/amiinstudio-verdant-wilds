using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using Amiin.Models;
using Amiin.Services;

namespace Amiin.ViewModels;

public partial class DownloadsViewModel : ObservableObject
{
    private readonly AppState _state;

    public ObservableCollection<GameModel> Games => _state.Games;

    public DownloadsViewModel(AppState state, NavigationService nav)
    {
        _state = state;
    }
}
