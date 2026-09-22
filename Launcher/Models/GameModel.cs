using CommunityToolkit.Mvvm.ComponentModel;

namespace Amiin.Models;

public enum GameStatus { Ready, UpdateAvailable, NotInstalled }

/// <summary>UI-facing wrapper around a signed <see cref="GameEntry"/> plus local install state.</summary>
public partial class GameModel : ObservableObject
{
    public GameEntry Entry { get; }

    public string Id => Entry.id;
    public string Title => Entry.title;
    public string Tagline => Entry.tagline;

    [ObservableProperty] private GameStatus status;
    [ObservableProperty] private double playtimeHours;
    [ObservableProperty] private string lastPlayed = "Never";
    [ObservableProperty] private string version;

    public GameModel(GameEntry entry, GameStatus status, string? installedVersion)
    {
        Entry = entry;
        this.status = status;
        version = installedVersion ?? entry.package.version;
    }

    public string StatusText => Status switch
    {
        GameStatus.Ready => "Ready to play",
        GameStatus.UpdateAvailable => "Update available",
        GameStatus.NotInstalled => "Not installed",
        _ => ""
    };

    public string PlayButtonLabel => Status switch
    {
        GameStatus.Ready => "Play",
        GameStatus.UpdateAvailable => "Update & Play",
        GameStatus.NotInstalled => "Download & Play",
        _ => "Play"
    };
}
