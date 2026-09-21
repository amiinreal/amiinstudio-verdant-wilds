using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Amiin;

public class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--wait" && int.TryParse(args[1],out var pid))
            try { Process.GetProcessById(pid).WaitForExit(15000); } catch (ArgumentException) { }
        Directory.CreateDirectory(Updates.Root);
        // The original downloaded executable doubles as the stable bootstrap.
        var installed=Updates.Installed("launcher","public");
        if (installed.Item2 is string current && !Path.GetFullPath(Environment.ProcessPath!).Equals(current,StringComparison.OrdinalIgnoreCase))
        {
            Process.Start(new ProcessStartInfo(current){UseShellExecute=true}); return;
        }
        using var mutex=new Mutex(true,"Local\\AmiinStudioLauncher",out bool owned);
        if (!owned) { MessageBox.Show("Amiin Launcher is already open."); return; }
        var app=new Application(); app.Run(new LauncherWindow());
    }
}

// Palette shared by both screens.
static class Palette
{
    public static readonly Color Ink = Color.FromRgb(9, 18, 17);
    public static readonly Color Panel = Color.FromRgb(15, 30, 28);
    public static readonly Color PanelLight = Color.FromRgb(20, 39, 36);
    public static readonly Color Border = Color.FromRgb(31, 54, 50);
    public static readonly Color Gold = Color.FromRgb(217, 179, 103);
    public static readonly Color GoldDim = Color.FromRgb(180, 150, 92);
    public static readonly Color Cream = Color.FromRgb(243, 232, 200);
    public static readonly Color Sage = Color.FromRgb(190, 210, 187);
    public static readonly Color Muted = Color.FromRgb(128, 152, 141);
    public static readonly Color Danger = Color.FromRgb(224, 140, 140);
}

public class LauncherWindow : Window
{
    // Auth screen.
    readonly TextBox name = new() { Height = 42, FontSize = 16, Padding = new Thickness(12, 9, 12, 9), BorderThickness = new Thickness(1) };
    readonly PasswordBox password = new() { Height = 42, FontSize = 16, Padding = new Thickness(12, 9, 12, 9), BorderThickness = new Thickness(1) };
    readonly TextBlock authStatus = Text("", 13, Palette.Danger);
    readonly Grid authScreen = new();

    // Library shell.
    readonly Grid shell = new() { Visibility = Visibility.Collapsed };
    readonly StackPanel gameRail = new() { Margin = new Thickness(0, 16, 0, 0) };
    readonly TextBlock accountChip = Text("", 13, Palette.Sage);
    readonly TextBlock gameTitle = Text("Select a game", 34, Palette.Cream);
    readonly TextBlock gameTagline = Text("", 16, Palette.Sage);
    readonly TextBlock gameNotes = Text("", 13, Palette.Muted);
    readonly Border gameArt = new() { CornerRadius = new CornerRadius(16), Height = 96, Width = 96, Margin = new Thickness(0, 0, 0, 20) };
    readonly TextBlock gameArtLabel = new() { FontSize = 30, FontWeight = FontWeights.Medium, Foreground = new SolidColorBrush(Palette.Cream), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
    readonly ComboBox channels = new() { Height = 30, FontSize = 13, Width = 150, HorizontalAlignment = HorizontalAlignment.Left };
    readonly ProgressBar progress = new() { Height = 5, Minimum = 0, Maximum = 100, Background = Brushes.Transparent };
    readonly TextBlock status = Text("", 13, Palette.Sage);
    readonly Button play = new() { Content = "Play", Height = 50, FontSize = 17, Width = 200, HorizontalAlignment = HorizontalAlignment.Right };

    Configuration? config;
    string token = "";
    bool working;
    Manifest? manifest;
    List<GameEntry> games = new();
    GameEntry? selected;

    public LauncherWindow()
    {
        Title = "Amiin Studio"; Width = 1180; Height = 740; MinWidth = 960; MinHeight = 640;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = new SolidColorBrush(Palette.Ink); Foreground = Brushes.WhiteSmoke;
        FontFamily = new FontFamily("Segoe UI");

        var root = new Grid(); Content = root;
        BuildAuthScreen(); root.Children.Add(authScreen);
        BuildShell(); root.Children.Add(shell);

        try
        {
            var path = Path.Combine(Updates.Root, "launcher-config.json");
            var bundled = Path.Combine(AppContext.BaseDirectory, "launcher-config.json");
            if (!File.Exists(path) && File.Exists(bundled)) File.Copy(bundled, path);
            config = JsonSerializer.Deserialize<Configuration>(File.ReadAllText(path), Updates.Json)!;
            Updates.SafeUrl(config.api, config.development);
            authStatus.Text = config.development ? "LOCAL TEST SERVICE · Your public server is not deployed yet." : "";
        }
        catch { authStatus.Foreground = new SolidColorBrush(Palette.Danger); authStatus.Text = "Setup required: the studio must configure its online service and signed release key before publishing this launcher."; }

        if (Environment.GetEnvironmentVariable("AMIIN_CAPTURE") is string capture)
            Loaded += (_, _) => Dispatcher.InvokeAsync(() =>
            {
                var bitmap = new RenderTargetBitmap((int)ActualWidth, (int)ActualHeight, 96, 96, PixelFormats.Pbgra32); bitmap.Render(this);
                var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap)); using var file = File.Create(capture); encoder.Save(file); Close();
            }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
    }

    // ---------- Auth screen ----------
    void BuildAuthScreen()
    {
        authScreen.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.15, GridUnitType.Star) });
        authScreen.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var brand = new Border { Background = new LinearGradientBrush(Palette.PanelLight, Palette.Ink, 90) };
        authScreen.Children.Add(brand);
        var hero = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(56) }; brand.Child = hero;
        var logo = Path.Combine(AppContext.BaseDirectory, "logo.png");
        if (File.Exists(logo)) hero.Children.Add(new Image { Source = new BitmapImage(new Uri(logo)), Height = 84, Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 0, 0, 28) });
        hero.Children.Add(Text("AMIIN STUDIO", 13, "#D7B878", 0.22));
        hero.Children.Add(Text("Your games.\nYour worlds.\nYour friends.", 44, "#F3E8C8"));
        hero.Children.Add(Text("One account unlocks every Amiin Studio game — starting with The Verdant Wilds.", 15, "#ADBCB1", margin: new Thickness(0, 16, 0, 0)));

        var right = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(56), MaxWidth = 380 };
        Grid.SetColumn(right, 1); authScreen.Children.Add(right);
        right.Children.Add(Text("Sign in to continue", 24, "#F3E8C8", margin: new Thickness(0, 0, 0, 24)));
        right.Children.Add(FieldLabel("EXPLORER NAME")); right.Children.Add(name);
        right.Children.Add(FieldLabel("PASSWORD · at least 12 characters", new Thickness(0, 14, 0, 6))); right.Children.Add(password);
        var row = new Grid { Margin = new Thickness(0, 18, 0, 0) };
        row.ColumnDefinitions.Add(new ColumnDefinition()); row.ColumnDefinitions.Add(new ColumnDefinition());
        var signIn = PrimaryButton("Sign in"); signIn.Click += async (_, _) => await Run(() => Authenticate(false));
        var create = SecondaryButton("Create account"); create.Margin = new Thickness(8, 0, 0, 0); Grid.SetColumn(create, 1); create.Click += async (_, _) => await Run(() => Authenticate(true));
        row.Children.Add(signIn); row.Children.Add(create); right.Children.Add(row);
        var recover = GhostButton("Recover account"); recover.HorizontalAlignment = HorizontalAlignment.Left; recover.Margin = new Thickness(0, 10, 0, 0); recover.Click += async (_, _) => await Run(Recover);
        right.Children.Add(recover);
        authStatus.Margin = new Thickness(0, 14, 0, 0); right.Children.Add(authStatus);
        right.Children.Add(Text("Launcher " + Updates.Version + "  ·  amiinstudio.no", 11, "#80988D", margin: new Thickness(0, 28, 0, 0)));

        // Enter submits sign-in from either field.
        KeyDown += async (_, e) => { if (e.Key == Key.Enter && authScreen.Visibility == Visibility.Visible && !working) await Run(() => Authenticate(false)); };
    }

    // ---------- Library shell ----------
    void BuildShell()
    {
        shell.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        shell.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        // Top bar.
        var topBar = new Border { Background = new SolidColorBrush(Palette.Panel), BorderBrush = new SolidColorBrush(Palette.Border), BorderThickness = new Thickness(0, 0, 0, 1), Padding = new Thickness(20, 12, 20, 12) };
        Grid.SetRow(topBar, 0); shell.Children.Add(topBar);
        var topGrid = new Grid(); topBar.Child = topGrid;
        topGrid.ColumnDefinitions.Add(new ColumnDefinition()); topGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var brandRow = new StackPanel { Orientation = Orientation.Horizontal };
        brandRow.Children.Add(new Border { Width = 26, Height = 26, CornerRadius = new CornerRadius(6), Background = new SolidColorBrush(Palette.Gold), Child = new TextBlock { Text = "A", FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Palette.Ink), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } });
        brandRow.Children.Add(new TextBlock { Text = "AMIIN STUDIO", FontSize = 13, FontWeight = FontWeights.Medium, Foreground = Brushes.WhiteSmoke, Margin = new Thickness(10, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center });
        topGrid.Children.Add(brandRow);
        var accountRow = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right }; Grid.SetColumn(accountRow, 1);
        accountRow.Children.Add(accountChip);
        var signOut = GhostButton("Sign out"); signOut.Margin = new Thickness(16, 0, 0, 0); signOut.Click += async (_, _) => await Run(SignOut);
        accountRow.Children.Add(signOut);
        topGrid.Children.Add(accountRow);

        // Body: rail + detail.
        var body = new Grid(); Grid.SetRow(body, 1); shell.Children.Add(body);
        body.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var rail = new Border { Width = 108, Background = new SolidColorBrush(Palette.Panel), BorderBrush = new SolidColorBrush(Palette.Border), BorderThickness = new Thickness(0, 0, 1, 0) };
        body.Children.Add(rail);
        var railScroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; rail.Child = railScroll;
        railScroll.Content = gameRail;
        var more = new Border { Width = 72, Height = 72, CornerRadius = new CornerRadius(14), Background = new SolidColorBrush(Palette.PanelLight), BorderBrush = new SolidColorBrush(Palette.Border), BorderThickness = new Thickness(1), Margin = new Thickness(18, 10, 18, 0), ToolTip = "More games are coming to Amiin Studio" };
        more.Child = new TextBlock { Text = "+", FontSize = 28, Foreground = new SolidColorBrush(Palette.Muted), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        gameRail.Children.Add(more);

        var detail = new Grid { Margin = new Thickness(48, 40, 48, 32) }; Grid.SetColumn(detail, 1); body.Children.Add(detail);
        detail.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        detail.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var info = new StackPanel { VerticalAlignment = VerticalAlignment.Top }; detail.Children.Add(info);
        gameArt.Background = new LinearGradientBrush(Palette.Gold, Palette.PanelLight, 45); gameArt.Child = gameArtLabel;
        info.Children.Add(gameArt);
        info.Children.Add(gameTitle);
        gameTagline.Margin = new Thickness(0, 6, 0, 0); info.Children.Add(gameTagline);
        gameNotes.Margin = new Thickness(0, 14, 0, 0); gameNotes.MaxWidth = 560; info.Children.Add(gameNotes);

        var actionBar = new Border { BorderBrush = new SolidColorBrush(Palette.Border), BorderThickness = new Thickness(0, 1, 0, 0), Padding = new Thickness(0, 20, 0, 0), Margin = new Thickness(0, 20, 0, 0) };
        Grid.SetRow(actionBar, 1); detail.Children.Add(actionBar);
        var actionGrid = new Grid(); actionBar.Child = actionGrid;
        actionGrid.ColumnDefinitions.Add(new ColumnDefinition()); actionGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var left = new StackPanel();
        left.Children.Add(FieldLabel("RELEASE CHANNEL")); channels.Margin = new Thickness(0, 4, 0, 10); left.Children.Add(channels);
        progress.Margin = new Thickness(0, 0, 0, 6); left.Children.Add(progress);
        left.Children.Add(status);
        actionGrid.Children.Add(left);
        PrimaryButtonStyle(play); Grid.SetColumn(play, 1); play.VerticalAlignment = VerticalAlignment.Bottom; play.Click += async (_, _) => await Run(UpdateAndPlay);
        actionGrid.Children.Add(play);

        channels.SelectionChanged += async (_, e) => { if (e.RemovedItems.Count > 0 && token.Length > 0) await Run(RefreshLibrary); };
    }

    // ---------- Helpers ----------
    static TextBlock Text(string text, double size, string color, double tracking = 0, Thickness? margin = null) =>
        new() { Text = text, FontSize = size, Foreground = (Brush)new BrushConverter().ConvertFromString(color)!, TextWrapping = TextWrapping.Wrap, Margin = margin ?? new Thickness(0, 0, 0, 10), FontWeight = tracking > 0 ? FontWeights.Medium : FontWeights.Normal };
    static TextBlock Text(string text, double size, Color color) => Text(text, size, ColorToHex(color));
    static string ColorToHex(Color c) => $"#{c.R:X2}{c.G:X2}{c.B:X2}";
    static TextBlock FieldLabel(string text, Thickness? margin = null) => new() { Text = text, FontSize = 11, Foreground = new SolidColorBrush(Palette.Gold), Margin = margin ?? new Thickness(0, 0, 0, 6) };
    static void PrimaryButtonStyle(Button b) { b.Background = new SolidColorBrush(Palette.Gold); b.Foreground = new SolidColorBrush(Palette.Ink); b.BorderThickness = new Thickness(0); b.FontWeight = FontWeights.SemiBold; b.Cursor = Cursors.Hand; b.Padding = new Thickness(18, 10, 18, 10); }
    static Button PrimaryButton(string text) { var b = new Button { Content = text, Height = 44 }; PrimaryButtonStyle(b); return b; }
    static Button SecondaryButton(string text) => new() { Content = text, Height = 44, Background = new SolidColorBrush(Palette.PanelLight), Foreground = Brushes.WhiteSmoke, BorderBrush = new SolidColorBrush(Palette.Border), BorderThickness = new Thickness(1), Cursor = Cursors.Hand };
    static Button GhostButton(string text) => new() { Content = text, Background = Brushes.Transparent, Foreground = new SolidColorBrush(Palette.Sage), BorderThickness = new Thickness(0), Cursor = Cursors.Hand, Padding = new Thickness(4), FontSize = 13 };
    static string Initials(string title)
    {
        var words = title.Split(' ', StringSplitOptions.RemoveEmptyEntries).Where(w => w.Length > 2 || char.IsUpper(w[0])).ToArray();
        if (words.Length == 0) words = title.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return string.Concat(words.Take(2).Select(w => char.ToUpperInvariant(w[0])));
    }

    async Task Run(Func<Task> action)
    {
        if (working) return; working = true; play.IsEnabled = false; channels.IsEnabled = false;
        try { await action(); }
        catch (Exception ex) { if (shell.Visibility == Visibility.Visible) status.Text = ex.Message; else { authStatus.Foreground = new SolidColorBrush(Palette.Danger); authStatus.Text = ex.Message; } }
        finally { working = false; play.IsEnabled = true; channels.IsEnabled = true; progress.IsIndeterminate = false; }
    }

    async Task<JsonElement> Api(string path, object? body = null, string? bearer = null)
    {
        if (config is null) throw new Exception("Online service is not configured yet.");
        using var request = new HttpRequestMessage(body is null ? HttpMethod.Get : HttpMethod.Post, Updates.SafeUrl(config.api.TrimEnd('/') + path, config.development));
        if (!string.IsNullOrEmpty(bearer ?? token)) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearer ?? token);
        if (body is not null) request.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(120));
        using var response = await Updates.Http.SendAsync(request, timeout.Token);
        var raw = await response.Content.ReadAsStringAsync(timeout.Token);
        JsonElement result;
        try { result = JsonDocument.Parse(raw).RootElement.Clone(); } catch { throw new Exception("Server is waking up or unavailable. Try again in a minute."); }
        if (!response.IsSuccessStatusCode) throw new Exception(FriendlyDetail(result));
        return result;
    }

    // FastAPI validation errors return `detail` as an array of {msg,...} objects, not a
    // string — without this, the raw JSON array was shown to the user verbatim.
    static string FriendlyDetail(JsonElement result)
    {
        if (!result.TryGetProperty("detail", out var detail)) return "Service request failed.";
        if (detail.ValueKind == JsonValueKind.String) return detail.GetString()!;
        if (detail.ValueKind == JsonValueKind.Array)
        {
            var messages = new List<string>();
            foreach (var item in detail.EnumerateArray())
                if (item.TryGetProperty("msg", out var msg)) messages.Add(msg.GetString()!.Replace("String should have at least", "Needs at least").Replace("String should have at most", "Needs at most"));
            return messages.Count > 0 ? string.Join(" ", messages.Distinct()) : "Check the form and try again.";
        }
        return "Service request failed.";
    }

    async Task Authenticate(bool register)
    {
        var trimmedName = name.Text.Trim();
        if (trimmedName.Length < 3) throw new Exception("Explorer name needs at least 3 characters.");
        if (password.Password.Length < 12) throw new Exception("Password needs at least 12 characters.");
        authStatus.Foreground = new SolidColorBrush(Palette.Sage); authStatus.Text = "Connecting / waking server…";
        var result = await Api(register ? "/auth/register" : "/auth/login", new { username = trimmedName, password = password.Password });
        password.Clear(); token = result.GetProperty("token").GetString()!;
        if (result.TryGetProperty("recovery_code", out var recovery))
            MessageBox.Show(this, "Save this recovery code in your password manager. It is shown only once.\n\n" + recovery.GetString(), "Your account recovery code");
        var me = await Api("/auth/me"); channels.Items.Clear();
        foreach (var channel in me.GetProperty("channels").EnumerateArray()) channels.Items.Add(channel.GetString());
        channels.SelectedIndex = 0;
        accountChip.Text = me.GetProperty("username").GetString();
        authScreen.Visibility = Visibility.Collapsed; shell.Visibility = Visibility.Visible;
        status.Text = "Checking for updates…";
        await RefreshLibrary();
    }

    async Task Recover()
    {
        var dialog = new Window { Title = "Recover your account", Owner = this, Width = 470, Height = 260, WindowStartupLocation = WindowStartupLocation.CenterOwner, Background = new SolidColorBrush(Palette.Panel), Foreground = Brushes.WhiteSmoke };
        var panel = new StackPanel { Margin = new Thickness(24) }; dialog.Content = panel;
        panel.Children.Add(new TextBlock { Text = "Enter the saved recovery code. Your password field\nwill become your NEW password.", Margin = new Thickness(0, 0, 0, 15), TextWrapping = TextWrapping.Wrap });
        var code = new TextBox { Height = 32 }; panel.Children.Add(code);
        var submit = PrimaryButton("Reset password"); submit.Margin = new Thickness(0, 20, 0, 0); submit.HorizontalAlignment = HorizontalAlignment.Left; panel.Children.Add(submit);
        submit.Click += (_, _) => dialog.DialogResult = true;
        if (dialog.ShowDialog() != true) return;
        var result = await Api("/auth/recover", new { username = name.Text.Trim(), password = password.Password, recovery_code = code.Text.Trim() });
        MessageBox.Show(this, "Password reset. Save your NEW recovery code:\n\n" + result.GetProperty("recovery_code").GetString());
        password.Clear(); authStatus.Foreground = new SolidColorBrush(Palette.Sage); authStatus.Text = "Password reset. Sign in with your new password.";
    }

    async Task SignOut()
    {
        if (token.Length > 0) { try { await Api("/auth/logout", new { }); } finally { } }
        token = ""; games.Clear(); gameRail.Children.Clear(); selected = null;
        shell.Visibility = Visibility.Collapsed; authScreen.Visibility = Visibility.Visible;
        authStatus.Foreground = new SolidColorBrush(Palette.Sage); authStatus.Text = "Signed out.";
    }

    // Fetches the release manifest for the selected channel and rebuilds the game rail.
    async Task RefreshLibrary()
    {
        var channel = channels.SelectedItem?.ToString() ?? "public"; Updates.SafeName(channel);
        var envelope = await Api("/releases/" + channel);
        manifest = Updates.Verify(envelope.GetRawText(), config!.publicKey, channel);
        games = manifest.games;
        var keepId = selected?.id;
        gameRail.Children.Clear();
        foreach (var entry in games)
        {
            var tile = new Border { Width = 72, Height = 72, CornerRadius = new CornerRadius(14), Margin = new Thickness(18, entry == games[0] ? 0 : 10, 18, 0), Cursor = Cursors.Hand, BorderThickness = new Thickness(2), Tag = entry };
            RenderTile(tile, entry, entry.id == (keepId ?? games[0].id));
            tile.MouseLeftButtonUp += (_, _) => SelectGame(entry);
            gameRail.Children.Add(tile);
        }
        var more = gameRail.Children.OfType<Border>().FirstOrDefault(b => b.Tag is null);
        if (more != null) { gameRail.Children.Remove(more); gameRail.Children.Add(more); }
        SelectGame(games.FirstOrDefault(g => g.id == keepId) ?? games.FirstOrDefault());
    }

    void RenderTile(Border tile, GameEntry entry, bool active)
    {
        tile.Background = new LinearGradientBrush(Palette.Gold, Palette.PanelLight, 45);
        tile.BorderBrush = new SolidColorBrush(active ? Palette.Gold : Colors.Transparent);
        tile.Child = new TextBlock { Text = Initials(entry.title), FontSize = 22, FontWeight = FontWeights.Medium, Foreground = new SolidColorBrush(Palette.Ink), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
    }

    void SelectGame(GameEntry? entry)
    {
        selected = entry;
        foreach (var tile in gameRail.Children.OfType<Border>())
            if (tile.Tag is GameEntry g) RenderTile(tile, g, g.id == entry?.id);
        if (entry is null)
        {
            gameTitle.Text = "No games published"; gameTagline.Text = "Check back soon."; gameNotes.Text = "";
            gameArtLabel.Text = "·"; play.IsEnabled = false; return;
        }
        play.IsEnabled = true;
        gameTitle.Text = entry.title; gameTagline.Text = entry.tagline; gameNotes.Text = manifest?.notes ?? "";
        gameArtLabel.Text = Initials(entry.title);
        var installed = Updates.Installed("game", channels.SelectedItem?.ToString() ?? "public", entry.id);
        play.Content = installed.Item1 is null ? "Download & play" : installed.Item1.version == entry.package.version ? "Play" : "Update & play";
    }

    async Task UpdateAndPlay()
    {
        if (token.Length == 0) throw new Exception("Sign in before downloading or playing.");
        if (selected is null) throw new Exception("Choose a game to play.");
        var chosen = selected; var channel = channels.SelectedItem?.ToString() ?? "public"; Updates.SafeName(channel);
        status.Text = "Checking signed releases / waking server…"; progress.IsIndeterminate = true;
        var envelope = await Api("/releases/" + channel);
        var release = Updates.Verify(envelope.GetRawText(), config!.publicKey, channel);
        var revisionFile = Path.Combine(Updates.Root, "revisions", channel + ".txt");
        long previous = File.Exists(revisionFile) ? long.Parse(File.ReadAllText(revisionFile)) : 0;
        if (release.revision < previous) throw new Exception("Server offered an older release manifest. Update refused.");
        Updates.AtomicText(revisionFile, release.revision.ToString());
        progress.IsIndeterminate = false;
        var reporter = new Progress<(double, string)>(v => { progress.Value = v.Item1; status.Text = v.Item2; });
        var game = release.games.FirstOrDefault(g => g.id == chosen.id) ?? throw new Exception("This game is no longer available on this channel.");
        var installed = Updates.Installed("game", channel, game.id);
        var action = Updates.ActionFor(release, Updates.Version, game, installed.Item1?.version);
        if (action == "launcher")
        {
            status.Text = "Launcher update required first. The game update will follow after restart.";
            var exe = await Updates.Install(release.launcher, "launcher", "public", config.development, reporter);
            Process.Start(new ProcessStartInfo(exe) { UseShellExecute = true, Arguments = "--wait " + Environment.ProcessId }); Close(); return;
        }
        string gamePath;
        if (action == "game" || installed.Item1?.sha256 != game.package.sha256) gamePath = await Updates.Install(game.package, "game", channel, config.development, reporter, game.id);
        else gamePath = installed.Item2!;
        // Recheck immediately before issuing a one-time credential and launching.
        var fresh = await Api("/releases/" + channel);
        var latest = Updates.Verify(fresh.GetRawText(), config.publicKey, channel);
        if (latest.revision != release.revision) throw new Exception("A new update was just published. Press Play again.");
        var ticket = await Api("/auth/launch-ticket", new { });
        var start = new ProcessStartInfo(gamePath) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(gamePath)! };
        start.Environment["AMIIN_API"] = config.api; start.Environment["AMIIN_CHANNEL"] = channel; start.Environment["AMIIN_GAME_ID"] = game.id;
        start.Environment["AMIIN_LAUNCH_TICKET"] = ticket.GetProperty("ticket").GetString();
        var pack = Path.Combine(start.WorkingDirectory, Path.GetFileNameWithoutExtension(game.package.entry) + ".pck");
        if (File.Exists(pack)) { start.ArgumentList.Add("--main-pack"); start.ArgumentList.Add(pack); }
        Process.Start(start); status.Text = chosen.title + " launched. Host a world to get your invite code.";
        SelectGame(chosen);
    }
}
