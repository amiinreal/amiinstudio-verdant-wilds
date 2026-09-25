using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using Amiin.Services;

namespace Amiin;

public class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--wait" && int.TryParse(args[1], out var pid))
            try { Process.GetProcessById(pid).WaitForExit(15000); } catch (ArgumentException) { }
        Directory.CreateDirectory(Updates.Root);

        // The original downloaded executable doubles as the stable bootstrap.
        var installed = Updates.Installed("launcher", "public");
        if (installed.Item2 is string current && !Path.GetFullPath(Environment.ProcessPath!).Equals(current, StringComparison.OrdinalIgnoreCase))
        {
            try { Process.Start(new ProcessStartInfo(current) { UseShellExecute = true }); }
            catch (System.ComponentModel.Win32Exception ex)
            {
                MessageBox.Show("Windows blocked the installed launcher from running (its publisher isn't recognized yet). " +
                    "Open Windows Security -> App & browser control -> Smart App Control and check its status.\n\n" + ex.Message,
                    "Amiin Studio Launcher");
            }
            return;
        }

        using var mutex = new Mutex(true, "Local\\AmiinStudioLauncher", out bool owned);
        if (!owned) { MessageBox.Show("Amiin Launcher is already open."); return; }

        var app = new Application();
        app.Resources.MergedDictionaries.Add(new ResourceDictionary { Source = new Uri("pack://application:,,,/Styles/LauncherStyles.xaml", UriKind.Absolute) });

        // Last-resort safety net: without this, any exception that escapes a command
        // handler (a network hiccup, a bad response, anything not already wrapped in its
        // own try/catch) takes down the whole launcher with no message at all.
        app.DispatcherUnhandledException += (_, e) =>
        {
            MessageBox.Show("Something went wrong and the last action couldn't finish:\n\n" + e.Exception.Message,
                "Amiin Studio Launcher");
            e.Handled = true;
        };

        var state = new AppState();
        AppState.Current = state;
        try
        {
            var path = Path.Combine(Updates.Root, "launcher-config.json");
            var bundled = Path.Combine(AppContext.BaseDirectory, "launcher-config.json");
            if (!File.Exists(path) && File.Exists(bundled)) File.Copy(bundled, path);
            state.Config = JsonSerializer.Deserialize<Configuration>(File.ReadAllText(path), Updates.Json)!;
            Updates.SafeUrl(state.Config.api, state.Config.development);
        }
        catch
        {
            MessageBox.Show("Setup required: the studio must configure its online service and signed release key before publishing this launcher.",
                "Amiin Studio Launcher");
        }

        var api = new ApiService(state);
        var navigation = new NavigationService(state, api);
        state.Navigation = navigation;
        navigation.NavigateToLogin();
        _ = TryAutoLoginAsync(state, api, navigation);

        var window = new MainWindow(navigation);
        app.Run(window);
    }

    // "Remember me": the login screen above is shown immediately so the window never looks
    // blank, and this swaps to the library once (if) the remembered token still checks out.
    private static async Task TryAutoLoginAsync(AppState state, ApiService api, NavigationService navigation)
    {
        var remembered = RememberedSession.Load();
        if (remembered is null || state.Config is null) return;
        try
        {
            state.Token = remembered.Value.Token;
            var me = await api.Send("/auth/me");
            state.Channels = me.GetProperty("channels").EnumerateArray().Select(c => c.GetString()!).ToList();
            state.Channel = state.Channels.FirstOrDefault() ?? "public";
            state.Username = me.GetProperty("username").GetString() ?? remembered.Value.Username;
            await navigation.LoadLibraryAsync();
            navigation.NavigateToLibrary();
        }
        catch
        {
            state.Token = "";
            RememberedSession.Clear();
            // Login screen (already showing) is left as-is for a manual sign-in.
        }
    }
}
