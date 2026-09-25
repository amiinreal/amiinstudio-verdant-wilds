using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Amiin.Services;

namespace Amiin.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly AppState _state;
    private readonly NavigationService _nav;

    public string Username => _state.Username;
    public string Channel => _state.Channel;
    public string LauncherVersion => Updates.Version;
    public string ApiEndpoint => _state.Config?.api ?? "";

    public SettingsViewModel(AppState state, NavigationService nav)
    {
        _state = state; _nav = nav;
    }

    [RelayCommand]
    private async Task SignOut() => await _nav.SignOutAsync();
}
