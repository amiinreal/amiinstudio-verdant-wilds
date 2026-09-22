using System.Collections.ObjectModel;
using Amiin.Models;

namespace Amiin.Services;

/// <summary>Process-wide session state: config, auth token, current channel and the signed manifest.</summary>
public class AppState
{
    /// <summary>Process-wide instance, set once at startup so shared controls (e.g. the
    /// sidebar) can read session info without depending on the current page's DataContext.</summary>
    public static AppState? Current { get; set; }

    public NavigationService? Navigation { get; set; }

    public Configuration? Config { get; set; }
    public string Token { get; set; } = "";
    public string Username { get; set; } = "";
    public string Channel { get; set; } = "public";
    public List<string> Channels { get; set; } = new() { "public" };
    public Manifest? Manifest { get; set; }
    public ObservableCollection<GameModel> Games { get; } = new();

    public bool IsSignedIn => Token.Length > 0;
}
