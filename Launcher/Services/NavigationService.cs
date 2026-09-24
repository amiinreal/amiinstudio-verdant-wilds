using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using Amiin.Models;
using Amiin.ViewModels;

namespace Amiin.Services;

/// <summary>Owns which screen is on-screen (Login / Library / GameDetail) plus the full-window
/// Install/Update/Launch overlay, and drives the real download → verify → install → launch
/// pipeline against <see cref="Updates"/> (unchanged from the original launcher).</summary>
public class NavigationService : ObservableObject
{
    private readonly AppState _state;
    private readonly ApiService _api;

    public Action? RequestCloseApplication { get; set; }

    private object? _currentViewModel;
    public object? CurrentViewModel { get => _currentViewModel; private set => SetProperty(ref _currentViewModel, value); }

    private StatusViewModel? _status;
    public StatusViewModel? Status { get => _status; private set => SetProperty(ref _status, value); }

    private bool _isStatusVisible;
    public bool IsStatusVisible { get => _isStatusVisible; private set => SetProperty(ref _isStatusVisible, value); }

    private bool _launcherUpdateAvailable;
    public bool LauncherUpdateAvailable { get => _launcherUpdateAvailable; private set => SetProperty(ref _launcherUpdateAvailable, value); }

    private string _launcherLatestVersion = "";
    public string LauncherLatestVersion { get => _launcherLatestVersion; private set => SetProperty(ref _launcherLatestVersion, value); }

    public NavigationService(AppState state, ApiService api)
    {
        _state = state; _api = api;
    }

    public void NavigateToLogin() => CurrentViewModel = new LoginViewModel(_state, _api, this);
    public void NavigateToLibrary() => CurrentViewModel = new LibraryViewModel(_state, this);
    public void NavigateToGameDetail(GameModel game) => CurrentViewModel = new GameDetailViewModel(game, _state, this);

    public async Task SignOutAsync()
    {
        if (_state.Token.Length > 0)
            try { await _api.Send("/auth/logout", new { }); } catch { /* best-effort */ }
        _state.Token = ""; _state.Games.Clear();
        NavigateToLogin();
    }

    /// <summary>Fetches the signed release manifest for the active channel and rebuilds the game list.</summary>
    public async Task LoadLibraryAsync()
    {
        if (_state.Config is null) throw new Exception("Online service is not configured yet.");
        var channel = _state.Channel; Updates.SafeName(channel);
        var envelope = await _api.Send("/releases/" + channel);
        var manifest = Updates.Verify(envelope.GetRawText(), _state.Config.publicKey, channel);
        _state.Manifest = manifest;

        LauncherUpdateAvailable = manifest.launcher.version != Updates.Version;
        LauncherLatestVersion = manifest.launcher.version;

        var keepId = _state.Games.FirstOrDefault()?.Id;
        _state.Games.Clear();
        foreach (var entry in manifest.games)
        {
            var (installedPackage, _) = Updates.Installed("game", channel, entry.id);
            var status = installedPackage is null
                ? GameStatus.NotInstalled
                : installedPackage.version != entry.package.version ? GameStatus.UpdateAvailable : GameStatus.Ready;
            _state.Games.Add(new GameModel(entry, status, installedPackage?.version));
        }
        _ = keepId;
    }

    /// <summary>Determines what's needed (launcher update / game install / game update / play),
    /// drives the overlay, and launches the game on success.</summary>
    public async Task PlayOrInstallAsync(GameModel game)
    {
        if (_state.Config is null || _state.Token.Length == 0) throw new Exception("Sign in before downloading or playing.");
        var channel = _state.Channel; Updates.SafeName(channel);

        // Everything from here on used to run partly outside the try/catch below, so a
        // manifest-fetch/verify failure (network hiccup, stale revision file, a game
        // dropped from the channel) threw straight through the RelayCommand and crashed
        // the whole launcher instead of showing an error in the status overlay.
        var status = new StatusViewModel { GameTitle = game.Title, Mode = LauncherMode.Launching, IsIndeterminate = true, ProgressText = "Checking for updates..." };
        Status = status; IsStatusVisible = true;

        var cancellation = new CancellationTokenSource();
        status.CancelRequested += () => cancellation.Cancel();
        status.DismissRequested += () => { IsStatusVisible = false; Status = null; };

        var mode = LauncherMode.Launching;
        try
        {
            var envelope = await _api.Send("/releases/" + channel);
            var release = Updates.Verify(envelope.GetRawText(), _state.Config.publicKey, channel);
            var revisionFile = Path.Combine(Updates.Root, "revisions", channel + ".txt");
            long previous = File.Exists(revisionFile) ? long.Parse(File.ReadAllText(revisionFile)) : 0;
            if (release.revision < previous) throw new Exception("Server offered an older release manifest. Update refused.");
            Updates.AtomicText(revisionFile, release.revision.ToString());

            var entry = release.games.FirstOrDefault(g => g.id == game.Id) ?? throw new Exception("This game is no longer available on this channel.");
            var (installedPackage, _) = Updates.Installed("game", channel, entry.id);
            var action = Updates.ActionFor(release, Updates.Version, entry, installedPackage?.version);

            mode = action switch
            {
                "launcher" => LauncherMode.Updating,
                "game" => installedPackage is null ? LauncherMode.Installing : LauncherMode.Updating,
                _ => LauncherMode.Launching
            };
            status.Mode = mode;

            var reporter = new Progress<(double Percent, string Text)>(v =>
            {
                status.Report(v.Percent, v.Text);
                status.IsIndeterminate = v.Percent <= 0 && mode != LauncherMode.Launching;
            });
            bool IsPaused() => status.IsPaused;

            if (action == "launcher")
            {
                status.ProgressText = "Launcher update required first. The game update will follow after restart.";
                await InstallAndRestartLauncherAsync(release.launcher, status, reporter, IsPaused, cancellation.Token);
                return;
            }

            string gamePath;
            if (action == "game" || installedPackage?.sha256 != entry.package.sha256)
                gamePath = await Updates.Install(entry.package, "game", channel, _state.Config.development, reporter, entry.id, cancellation.Token, IsPaused);
            else
                gamePath = Updates.Installed("game", channel, entry.id).Item2!;

            // Flip to Ready as soon as the files are actually on disk, not after the launch
            // below also succeeds -- otherwise a launch failure (missing dependency, blocked
            // by antivirus, whatever) leaves the library card stuck showing "Not installed"
            // and the download icon even though the game genuinely did finish downloading.
            game.Status = GameStatus.Ready;
            game.Version = entry.package.version;

            status.Mode = LauncherMode.Launching;
            status.IsIndeterminate = true;
            status.ProgressText = "Preparing your session...";

            // Recheck immediately before issuing a one-time credential and launching.
            var fresh = await _api.Send("/releases/" + channel);
            var latest = Updates.Verify(fresh.GetRawText(), _state.Config.publicKey, channel);
            if (latest.revision != release.revision) throw new Exception("A new update was just published. Press Play again.");

            var ticket = await _api.Send("/auth/launch-ticket", new { });
            var start = new ProcessStartInfo(gamePath) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(gamePath)! };
            start.Environment["AMIIN_API"] = _state.Config.api;
            start.Environment["AMIIN_CHANNEL"] = channel;
            start.Environment["AMIIN_GAME_ID"] = entry.id;
            start.Environment["AMIIN_LAUNCH_TICKET"] = ticket.GetProperty("ticket").GetString();
            var pack = Path.Combine(start.WorkingDirectory, Path.GetFileNameWithoutExtension(entry.package.entry) + ".pck");
            if (File.Exists(pack)) { start.ArgumentList.Add("--main-pack"); start.ArgumentList.Add(pack); }
            SafeStart(start);
        }
        catch (OperationCanceledException)
        {
            // User pressed Cancel; nothing went wrong, just close the overlay.
        }
        catch (Exception ex)
        {
            status.Mode = LauncherMode.Failed;
            status.ErrorMessage = ex.Message;
            IsStatusVisible = true;
            return; // leave the overlay up so the user actually sees the error
        }
        finally
        {
            if (status.Mode != LauncherMode.Failed) { IsStatusVisible = false; Status = null; }
        }
    }

    /// <summary>Updates just the launcher, independent of any game -- used by the "Launcher
    /// update available" banner so the user doesn't have to click Play on a game first.</summary>
    public async Task UpdateLauncherAsync()
    {
        if (_state.Config is null) throw new Exception("Online service is not configured yet.");
        var channel = _state.Channel; Updates.SafeName(channel);

        var status = new StatusViewModel { GameTitle = "Amiin Studio Launcher", Mode = LauncherMode.Updating, ProgressText = "Checking for updates..." };
        Status = status; IsStatusVisible = true;
        var cancellation = new CancellationTokenSource();
        status.CancelRequested += () => cancellation.Cancel();
        status.DismissRequested += () => { IsStatusVisible = false; Status = null; };

        try
        {
            var envelope = await _api.Send("/releases/" + channel);
            var release = Updates.Verify(envelope.GetRawText(), _state.Config.publicKey, channel);
            if (release.launcher.version == Updates.Version)
            {
                LauncherUpdateAvailable = false;
                return; // someone else already updated it, or it was a stale banner
            }

            var reporter = new Progress<(double Percent, string Text)>(v =>
            {
                status.Report(v.Percent, v.Text);
                status.IsIndeterminate = v.Percent <= 0;
            });
            await InstallAndRestartLauncherAsync(release.launcher, status, reporter, () => status.IsPaused, cancellation.Token);
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            status.Mode = LauncherMode.Failed;
            status.ErrorMessage = ex.Message;
            IsStatusVisible = true;
            return;
        }
        finally
        {
            if (status.Mode != LauncherMode.Failed) { IsStatusVisible = false; Status = null; }
        }
    }

    private async Task InstallAndRestartLauncherAsync(Package launcherPackage, StatusViewModel status, IProgress<(double, string)> reporter, Func<bool> isPaused, CancellationToken cancellationToken)
    {
        status.Mode = LauncherMode.Updating;
        var exe = await Updates.Install(launcherPackage, "launcher", "public", _state.Config!.development, reporter, cancellationToken: cancellationToken, isPaused: isPaused);

        status.ProgressText = "Starting the updated launcher...";
        var updated = SafeStart(new ProcessStartInfo(exe) { UseShellExecute = true, Arguments = "--wait " + Environment.ProcessId });
        // Windows (antivirus, Smart App Control) can kill a freshly-downloaded exe a
        // moment after it starts. Never close this still-working copy until the new
        // one has proven it's actually staying up -- otherwise a blocked update leaves
        // the user with nothing running at all.
        await Task.Delay(2000, cancellationToken);
        if (updated is null || updated.HasExited)
            throw new Exception("The updated launcher didn't stay open -- it may have been blocked or removed by antivirus or Smart App Control. " +
                "Your current version is unaffected and still works; check Windows Security, then try updating again.");

        RequestCloseApplication?.Invoke();
    }

    // Windows (Smart App Control / WDAC / SmartScreen) can silently refuse to start an
    // unsigned or not-yet-reputable executable. Without this, that surfaced as an opaque
    // "Object reference not set to an instance of an object" further down the call chain.
    private static Process? SafeStart(ProcessStartInfo info)
    {
        try { return Process.Start(info); }
        catch (Win32Exception ex)
        {
            throw new Exception("Windows blocked this file from running (its publisher isn't recognized yet). " +
                "Open Windows Security -> App & browser control -> Smart App Control and check its status, " +
                "or right-click the downloaded file -> Properties -> Unblock. (" + ex.Message + ")");
        }
    }
}
