using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Amiin.Models;
using Amiin.Services;

namespace Amiin.ViewModels;

public partial class GameDetailViewModel : ObservableObject
{
    private readonly AppState _state;
    private readonly NavigationService _nav;

    public GameModel Game { get; }

    [ObservableProperty] private string selectedTab = "Overview";

    public string Description => _state.Manifest?.notes is { Length: > 0 } notes
        ? notes
        : $"{Game.Title} is one of the worlds available through Amiin Studio. Sign in, download, and step in — updates are delivered automatically and verified before install.";

    // The signed manifest only carries what the launcher needs to install and run a build
    // (id/title/tagline/version); these catalog fields aren't part of that contract, so
    // they're sensible static placeholders until a catalog endpoint exists.
    public string Developer => "Amiin Studio";
    public string Publisher => "Amiin Studio";
    public string Genre => "Adventure · Survival";
    public string ReleaseDate => "Early Access";
    public string SizeOnDisk => "—";
    public string RequirementOS => "Windows 10 64-bit or later";
    public string RequirementCpu => "Quad-core, 2.5 GHz+";
    public string RequirementGpu => "DirectX 11 compatible, 2 GB VRAM";
    public string RequirementRam => "8 GB";
    public string RequirementStorage => "10 GB available space";

    public GameDetailViewModel(GameModel game, AppState state, NavigationService nav)
    {
        Game = game; _state = state; _nav = nav;
    }

    [RelayCommand] private void SelectTab(string tab) => SelectedTab = tab;

    [RelayCommand] private void Back() => _nav.NavigateToLibrary();

    [RelayCommand] private async Task Play() => await _nav.PlayOrInstallAsync(Game);
}
