using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Amiin.Models;
using Amiin.Services;

namespace Amiin.ViewModels;

public partial class LibraryViewModel : ObservableObject
{
    private readonly AppState _state;
    private readonly NavigationService _nav;

    public ObservableCollection<GameModel> Games => _state.Games;
    public GameModel? FeaturedGame => Games.FirstOrDefault();
    public NavigationService Nav => _nav;

    [ObservableProperty] private string searchText = "";
    public string Username => _state.Username;

    public LibraryViewModel(AppState state, NavigationService nav)
    {
        _state = state; _nav = nav;
        _state.Games.CollectionChanged += (_, _) => OnPropertyChanged(nameof(FeaturedGame));
    }

    [RelayCommand]
    private void OpenGame(GameModel? game)
    {
        if (game is null) return;
        _nav.NavigateToGameDetail(game);
    }

    [RelayCommand]
    private async Task PlayGame(GameModel? game)
    {
        if (game is null) return;
        await _nav.PlayOrInstallAsync(game);
    }

    [RelayCommand]
    private async Task Refresh() => await _nav.LoadLibraryAsync();

    [RelayCommand]
    private async Task UpdateLauncher() => await _nav.UpdateLauncherAsync();

    [RelayCommand]
    private async Task SignOut() => await _nav.SignOutAsync();
}
