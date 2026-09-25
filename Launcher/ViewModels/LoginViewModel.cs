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
    [ObservableProperty] private bool rememberMe;
    public string RecoveryToggleLabel => IsRecoveryMode ? "Back to sign in" : "Recover account";

    partial void OnIsRecoveryModeChanged(bool value)
    {
        OnPropertyChanged(nameof(RecoveryToggleLabel));
        OnPropertyChanged(nameof(ShowSignInForm));
        OnPropertyChanged(nameof(ShowRecoveryLink));
    }

    // Forgot-password (email + one-time code), separate from the long-recovery-code flow above.
    [ObservableProperty] private bool isForgotMode;
    [ObservableProperty] private bool otpRequested;
    [ObservableProperty] private string otpCode = "";
    [ObservableProperty] private string newPassword = "";
    public string ForgotToggleLabel => IsForgotMode ? "Back to sign in" : "Forgot password?";

    partial void OnIsForgotModeChanged(bool value)
    {
        OnPropertyChanged(nameof(ForgotToggleLabel));
        OnPropertyChanged(nameof(ShowSignInForm));
        OnPropertyChanged(nameof(ShowRequestOtpButton));
        OnPropertyChanged(nameof(ShowOtpFields));
        OnPropertyChanged(nameof(ShowForgotLink));
    }

    partial void OnOtpRequestedChanged(bool value)
    {
        OnPropertyChanged(nameof(ShowRequestOtpButton));
        OnPropertyChanged(nameof(ShowOtpFields));
    }

    public bool ShowSignInForm => !IsRecoveryMode && !IsForgotMode;
    public bool ShowRequestOtpButton => IsForgotMode && !OtpRequested;
    public bool ShowOtpFields => IsForgotMode && OtpRequested;
    public bool ShowRecoveryLink => !IsForgotMode;
    public bool ShowForgotLink => !IsRecoveryMode;

    // Shown once, right after a successful sign-in/create-account, only for an account that
    // has no email on file yet -- lets the user add one so they can use OTP-based recovery.
    [ObservableProperty] private bool needsEmailPrompt;
    [ObservableProperty] private string email = "";

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
        IsForgotMode = false;
        StatusMessage = ""; StatusIsError = false;
    }

    [RelayCommand]
    private void ToggleForgot()
    {
        IsForgotMode = !IsForgotMode;
        IsRecoveryMode = false;
        OtpRequested = false;
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

    [RelayCommand]
    private async Task RequestOtp()
    {
        await Run(async () =>
        {
            var trimmed = Username.Trim();
            if (trimmed.Length < 3) throw new Exception("Enter your explorer name first.");
            await _api.Send("/auth/forgot-password", new { username = trimmed });
            StatusIsError = false;
            // Deliberately vague: the backend gives the same response whether or not the
            // account/email exists, so this can't be used to discover registered names.
            StatusMessage = "If that account has an email on file, a 6-digit code was sent to it.";
            OtpRequested = true;
        });
    }

    [RelayCommand]
    private async Task ConfirmOtpReset()
    {
        await Run(async () =>
        {
            var trimmed = Username.Trim();
            if (trimmed.Length < 3) throw new Exception("Enter your explorer name first.");
            if (OtpCode.Trim().Length != 6) throw new Exception("Enter the 6-digit code from your email.");
            if (NewPassword.Length < 12) throw new Exception("New password needs at least 12 characters.");
            var result = await _api.Send("/auth/reset-password-otp", new { username = trimmed, password = NewPassword, otp = OtpCode.Trim() });
            NewPassword = ""; OtpCode = "";
            StatusIsError = false;
            StatusMessage = "Password reset. Save your NEW recovery code: " + result.GetProperty("recovery_code").GetString();
            IsForgotMode = false; OtpRequested = false;
        });
    }

    [RelayCommand]
    private async Task SaveEmail()
    {
        await Run(async () =>
        {
            var trimmed = Email.Trim();
            if (!trimmed.Contains('@')) throw new Exception("That doesn't look like a valid email address.");
            await _api.Send("/auth/set-email", new { email = trimmed });
            NeedsEmailPrompt = false;
            await FinishSignIn();
        });
    }

    [RelayCommand]
    private async Task SkipEmail()
    {
        NeedsEmailPrompt = false;
        await FinishSignIn();
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

            var hasEmail = result.TryGetProperty("has_email", out var he) && he.GetBoolean();
            if (!hasEmail)
            {
                NeedsEmailPrompt = true;
                return; // FinishSignIn runs after the user saves an email or skips the prompt.
            }

            await FinishSignIn();
        });
    }

    private async Task FinishSignIn()
    {
        var me = await _api.Send("/auth/me");
        _state.Channels = me.GetProperty("channels").EnumerateArray().Select(c => c.GetString()!).ToList();
        _state.Channel = _state.Channels.FirstOrDefault() ?? "public";
        _state.Username = me.GetProperty("username").GetString() ?? Username.Trim();

        if (RememberMe) RememberedSession.Save(_state.Token, _state.Username);
        else RememberedSession.Clear();

        await _nav.LoadLibraryAsync();
        _nav.NavigateToLibrary();
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
