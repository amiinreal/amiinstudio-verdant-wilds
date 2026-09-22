using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Amiin.Services;

namespace Amiin.ViewModels;

public partial class LoginViewModel : ObservableObject
{
    private readonly AppState _state;
    private readonly ApiService _api;
    private readonly NavigationService _nav;

    [ObservableProperty] private string username = "";
    [ObservableProperty] private string password = "";
    [ObservableProperty] private string recoveryCode = "";
    [ObservableProperty] private string statusMessage = "";
    [ObservableProperty] private bool statusIsError;
    [ObservableProperty] private bool isBusy;
    [ObservableProperty] private bool isRecoveryMode;
    public string RecoveryToggleLabel => IsRecoveryMode ? "Back to sign in" : "Recover account";

    partial void OnIsRecoveryModeChanged(bool value) => OnPropertyChanged(nameof(RecoveryToggleLabel));

    [ObservableProperty] private string versionLabel = "Launcher " + Updates.Version;
    [ObservableProperty] private string devBanner = "";

    public LoginViewModel(AppState state, ApiService api, NavigationService nav)
    {
        _state = state; _api = api; _nav = nav;
        if (_state.Config?.development == true) DevBanner = "LOCAL TEST SERVICE · Your public server is not deployed yet.";
    }

    [RelayCommand] private Task SignIn() => Authenticate(register: false);
    [RelayCommand] private Task CreateAccount() => Authenticate(register: true);

    [RelayCommand]
    private void ToggleRecovery()
    {
        IsRecoveryMode = !IsRecoveryMode;
        StatusMessage = ""; StatusIsError = false;
    }

    [RelayCommand]
    private async Task ConfirmRecovery()
    {
        await Run(async () =>
        {
            if (Username.Trim().Length < 3) throw new Exception("Enter your explorer name first.");
            if (Password.Length < 12) throw new Exception("New password needs at least 12 characters.");
            var result = await _api.Send("/auth/recover", new { username = Username.Trim(), password = Password, recovery_code = RecoveryCode.Trim() });
            Password = "";
            StatusIsError = false;
            StatusMessage = "Password reset. Save your NEW recovery code: " + result.GetProperty("recovery_code").GetString();
            IsRecoveryMode = false;
        });
    }

    private async Task Authenticate(bool register)
    {
        await Run(async () =>
        {
            var trimmed = Username.Trim();
            if (trimmed.Length < 3) throw new Exception("Explorer name needs at least 3 characters.");
            if (Password.Length < 12) throw new Exception("Password needs at least 12 characters.");
            StatusIsError = false; StatusMessage = "Connecting / waking server...";

            var result = await _api.Send(register ? "/auth/register" : "/auth/login", new { username = trimmed, password = Password });
            Password = "";
            _state.Token = result.GetProperty("token").GetString()!;

            if (result.TryGetProperty("recovery_code", out var recovery))
                StatusMessage = "Save this recovery code somewhere safe (shown once): " + recovery.GetString();

            var me = await _api.Send("/auth/me");
            _state.Channels = me.GetProperty("channels").EnumerateArray().Select(c => c.GetString()!).ToList();
            _state.Channel = _state.Channels.FirstOrDefault() ?? "public";
            _state.Username = me.GetProperty("username").GetString() ?? trimmed;

            await _nav.LoadLibraryAsync();
            _nav.NavigateToLibrary();
        });
    }

    private async Task Run(Func<Task> action)
    {
        if (IsBusy) return;
        IsBusy = true;
        try { await action(); }
        catch (Exception ex) { StatusIsError = true; StatusMessage = ex.Message; }
        finally { IsBusy = false; }
    }
}
