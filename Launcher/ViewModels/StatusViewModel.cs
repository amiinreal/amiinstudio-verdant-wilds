using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Amiin.Models;

namespace Amiin.ViewModels;

/// <summary>Drives the full-window Install / Update / Launch overlay. Callers report progress
/// through <see cref="Report"/>, which an <see cref="IProgress{T}"/> adapter forwards from
/// <see cref="Updates.Install"/>.</summary>
public partial class StatusViewModel : ObservableObject
{
    [ObservableProperty] private LauncherMode mode;
    [ObservableProperty] private string gameTitle = "";
    [ObservableProperty] private double progressPercent;
    [ObservableProperty] private string progressText = "";
    [ObservableProperty] private bool isIndeterminate;
    [ObservableProperty] private string speedText = "--";
    [ObservableProperty] private string sizeText = "--";
    [ObservableProperty] private string timeLeftText = "--";
    [ObservableProperty] private bool isPaused;
    [ObservableProperty] private bool canCancel = true;
    [ObservableProperty] private string errorMessage = "";

    public event Action? CancelRequested;
    public event Action? DismissRequested;

    public string Title => Mode switch
    {
        LauncherMode.Installing => $"Installing {GameTitle}",
        LauncherMode.Updating => $"Updating {GameTitle}",
        LauncherMode.Launching => $"Launching {GameTitle}",
        LauncherMode.Failed => $"Couldn't start {GameTitle}",
        _ => GameTitle
    };

    public string Subtitle => Mode switch
    {
        LauncherMode.Installing => "Setting up game files",
        LauncherMode.Updating => "Applying the latest patch",
        LauncherMode.Launching => "Preparing your session",
        LauncherMode.Failed => "",
        _ => ""
    };

    public bool ShowProgressBar => Mode != LauncherMode.Launching && Mode != LauncherMode.Failed;
    public bool ShowSpinner => Mode == LauncherMode.Launching;
    public bool ShowPause => Mode != LauncherMode.Launching && Mode != LauncherMode.Failed;
    public bool ShowError => Mode == LauncherMode.Failed;

    partial void OnModeChanged(LauncherMode value)
    {
        OnPropertyChanged(nameof(Title));
        OnPropertyChanged(nameof(Subtitle));
        OnPropertyChanged(nameof(ShowProgressBar));
        OnPropertyChanged(nameof(ShowSpinner));
        OnPropertyChanged(nameof(ShowPause));
        OnPropertyChanged(nameof(ShowError));
    }

    partial void OnGameTitleChanged(string value)
    {
        OnPropertyChanged(nameof(Title));
    }

    public void Report(double percent, string text)
    {
        ProgressPercent = percent;
        ProgressText = text;
    }

    [RelayCommand]
    private void TogglePause() => IsPaused = !IsPaused;

    [RelayCommand]
    private void Cancel() => CancelRequested?.Invoke();

    [RelayCommand]
    private void Dismiss() => DismissRequested?.Invoke();
}
