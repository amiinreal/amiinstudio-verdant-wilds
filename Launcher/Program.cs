using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
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

public class LauncherWindow : Window
{
    readonly TextBox name=new(){Height=38,FontSize=17};
    readonly PasswordBox password=new(){Height=38,FontSize=17};
    readonly ComboBox channels=new(){Height=36,FontSize=16};
    readonly TextBlock status=new(){TextWrapping=TextWrapping.Wrap,FontSize=15,Foreground=Brushes.Bisque};
    readonly TextBlock notes=new(){TextWrapping=TextWrapping.Wrap,FontSize=15,Foreground=new SolidColorBrush(Color.FromRgb(180,203,190))};
    readonly ProgressBar progress=new(){Height=7,Minimum=0,Maximum=100};
    readonly Button play=new(){Content="Sign in to play",Height=54,FontSize=20};
    readonly StackPanel auth=new();
    Configuration? config;
    string token="";
    bool working;
    public LauncherWindow()
    {
        Title="Amiin Studio • The Verdant Wilds"; Width=1080; Height=710; MinWidth=920; MinHeight=660;
        WindowStartupLocation=WindowStartupLocation.CenterScreen;
        Background=new SolidColorBrush(Color.FromRgb(11,25,24)); Foreground=Brushes.WhiteSmoke;
        FontFamily=new FontFamily("Segoe UI");
        var grid=new Grid{Margin=new Thickness(32)}; Content=grid;
        grid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1.25,GridUnitType.Star)});
        grid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});
        var art=new Border{CornerRadius=new CornerRadius(20),Padding=new Thickness(32),Margin=new Thickness(0,0,32,0),Background=new LinearGradientBrush(Color.FromRgb(39,80,64),Color.FromRgb(11,35,33),90)};
        grid.Children.Add(art);
        var hero=new StackPanel{VerticalAlignment=VerticalAlignment.Center}; art.Child=hero;
        var logo=Path.Combine(AppContext.BaseDirectory,"logo.png");
        if(File.Exists(logo)) hero.Children.Add(new Image{Source=new BitmapImage(new Uri(logo)),Height=100,Stretch=Stretch.Uniform,HorizontalAlignment=HorizontalAlignment.Left,Margin=new Thickness(0,0,0,25)});
        hero.Children.Add(Text("AMIIN STUDIO",16,"#D7B878"));
        hero.Children.Add(Text("THE\nVERDANT\nWILDS",52,"#F3E8C8"));
        hero.Children.Add(Text("A world worth coming home to.",20,"#BED2BB"));
        hero.Children.Add(Text("Gather in ancient forests. Build your home.\nInvite friends into your own adventure.",16,"#ADBCB1"));
        hero.Children.Add(Text("HOSTED BY YOU  ·  CONNECTED TOGETHER",11,"#D7B878"));
        var right=new StackPanel{VerticalAlignment=VerticalAlignment.Center}; Grid.SetColumn(right,1); grid.Children.Add(right);
        right.Children.Add(Text("Your next adventure",29,"#F3E8C8"));
        right.Children.Add(Text("One account. Your worlds. Your friends.",15,"#ADBCB1"));
        right.Children.Add(auth);
        auth.Children.Add(Text("EXPLORER NAME",11,"#D7B878")); auth.Children.Add(name);
        auth.Children.Add(Text("PASSWORD · at least 12 characters",11,"#D7B878")); auth.Children.Add(password);
        var row=new UniformGrid{Columns=2,Margin=new Thickness(0,16,0,8)}; auth.Children.Add(row);
        AddButton(row,"Sign in",()=>Authenticate(false)); AddButton(row,"Create account",()=>Authenticate(true));
        AddButton(auth,"Recover account",Recover);
        right.Children.Add(Text("RELEASE CHANNEL",11,"#D7B878")); right.Children.Add(channels);
        channels.Items.Add("public"); channels.SelectedIndex=0;
        right.Children.Add(Text("Test channels appear here when Amiin Studio grants your account access. They keep separate game installs and worlds.",12,"#ADBCB1"));
        notes.Margin=new Thickness(0,8,0,16); right.Children.Add(notes);
        right.Children.Add(progress); status.Margin=new Thickness(0,12,0,16); right.Children.Add(status);
        StyleButton(play); play.Click+=async(_,_)=>await Run(UpdateAndPlay); right.Children.Add(play);
        AddButton(right,"Sign out",SignOut);
        right.Children.Add(Text("Launcher "+Updates.Version+"  ·  amiinstudio.no",11,"#80988D"));
        try
        {
            var path=Path.Combine(Updates.Root,"launcher-config.json");
            var bundled=Path.Combine(AppContext.BaseDirectory,"launcher-config.json");
            if(!File.Exists(path) && File.Exists(bundled)) File.Copy(bundled,path);
            config=JsonSerializer.Deserialize<Configuration>(File.ReadAllText(path),Updates.Json)!;
            Updates.SafeUrl(config.api,config.development);
            status.Text="Sign in or create your explorer account.";
            if(config.development) status.Text="LOCAL TEST SERVICE · Your public server is not deployed yet.";
        }
        catch { status.Text="Setup required: the studio must configure its online service and signed release key before publishing this launcher."; }
		if(Environment.GetEnvironmentVariable("AMIIN_CAPTURE") is string capture)
			Loaded+=(_,_)=>Dispatcher.InvokeAsync(()=>{
				var bitmap=new RenderTargetBitmap((int)ActualWidth,(int)ActualHeight,96,96,PixelFormats.Pbgra32);bitmap.Render(this);
				var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));using var file=File.Create(capture);encoder.Save(file);Close();
			},System.Windows.Threading.DispatcherPriority.ApplicationIdle);
    }
    static TextBlock Text(string text,double size,string color)=>new(){Text=text,FontSize=size,Foreground=(Brush)new BrushConverter().ConvertFromString(color)!,TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,0,0,14)};
    static void StyleButton(Button button) { button.Background=new SolidColorBrush(Color.FromRgb(217,179,103));button.Foreground=new SolidColorBrush(Color.FromRgb(18,36,30));button.BorderThickness=new Thickness(0);button.Padding=new Thickness(12,8,12,8);button.Cursor=System.Windows.Input.Cursors.Hand; }
    void AddButton(Panel parent,string caption,Func<Task> action) { var button=new Button{Content=caption,Margin=new Thickness(0,3,8,3)}; StyleButton(button);button.Click+=async(_,_)=>await Run(action);parent.Children.Add(button); }
    async Task Run(Func<Task> action)
    {
        if(working)return;working=true;play.IsEnabled=false;auth.IsEnabled=false;channels.IsEnabled=false;
        try{await action();}catch(Exception ex){status.Text=ex.Message;}
        finally{working=false;play.IsEnabled=true;auth.IsEnabled=true;channels.IsEnabled=true;progress.IsIndeterminate=false;}
    }
    async Task<JsonElement> Api(string path,object? body=null,string? bearer=null)
    {
        if(config is null)throw new Exception("Online service is not configured yet.");
        using var request=new HttpRequestMessage(body is null?HttpMethod.Get:HttpMethod.Post,Updates.SafeUrl(config.api.TrimEnd('/')+path,config.development));
        if(!string.IsNullOrEmpty(bearer??token))request.Headers.Authorization=new AuthenticationHeaderValue("Bearer",bearer??token);
        if(body is not null)request.Content=new StringContent(JsonSerializer.Serialize(body),Encoding.UTF8,"application/json");
        using var timeout=new CancellationTokenSource(TimeSpan.FromSeconds(120));
        using var response=await Updates.Http.SendAsync(request,timeout.Token);
        var raw=await response.Content.ReadAsStringAsync(timeout.Token);
        JsonElement result;
        try{result=JsonDocument.Parse(raw).RootElement.Clone();}catch{throw new Exception("Server is waking up or unavailable. Try again in a minute.");}
        if(!response.IsSuccessStatusCode)throw new Exception(result.TryGetProperty("detail",out var detail)?detail.ToString():"Service request failed.");
        return result;
    }
    async Task Authenticate(bool register)
    {
        status.Text="Connecting / waking server…";progress.IsIndeterminate=true;
        var result=await Api(register?"/auth/register":"/auth/login",new{username=name.Text.Trim(),password=password.Password});
        password.Clear();token=result.GetProperty("token").GetString()!;
        if(result.TryGetProperty("recovery_code",out var recovery))
            MessageBox.Show(this,"Save this recovery code in your password manager. It is shown only once.\n\n"+recovery.GetString(),"Your account recovery code");
        var me=await Api("/auth/me");channels.Items.Clear();
        foreach(var channel in me.GetProperty("channels").EnumerateArray())channels.Items.Add(channel.GetString());channels.SelectedIndex=0;
        auth.Visibility=Visibility.Collapsed;play.Content="Update & play";status.Text="Welcome, "+me.GetProperty("username").GetString()+". Ready to check for updates.";
    }
    async Task Recover()
    {
        var dialog=new Window{Title="Recover your account",Owner=this,Width=470,Height=260,WindowStartupLocation=WindowStartupLocation.CenterOwner};
        var panel=new StackPanel{Margin=new Thickness(24)};dialog.Content=panel;
        panel.Children.Add(new TextBlock{Text="Enter the saved recovery code. Your password field\nwill become your NEW password.",Margin=new Thickness(0,0,0,15)});
        var code=new TextBox{Height=32};panel.Children.Add(code);
        var submit=new Button{Content="Reset password",Margin=new Thickness(0,20,0,0)};panel.Children.Add(submit);submit.Click+=(_,_)=>dialog.DialogResult=true;
        if(dialog.ShowDialog()!=true)return;
        var result=await Api("/auth/recover",new{username=name.Text.Trim(),password=password.Password,recovery_code=code.Text.Trim()});
        MessageBox.Show(this,"Password reset. Save your NEW recovery code:\n\n"+result.GetProperty("recovery_code").GetString());password.Clear();status.Text="Password reset. Sign in with your new password.";
    }
    async Task SignOut()
    {
        if(token.Length>0){try{await Api("/auth/logout",new{});}finally{token="";auth.Visibility=Visibility.Visible;play.Content="Sign in to play";status.Text="Signed out.";}}
    }
    async Task UpdateAndPlay()
    {
        if(token.Length==0)throw new Exception("Sign in before downloading or playing.");
        var channel=channels.SelectedItem?.ToString()??"public";Updates.SafeName(channel);
        status.Text="Checking signed releases / waking server…";progress.IsIndeterminate=true;
        var envelope=await Api("/releases/"+channel);
        var release=Updates.Verify(envelope.GetRawText(),config!.publicKey,channel);
        var revisionFile=Path.Combine(Updates.Root,"revisions",channel+".txt");
        long previous=File.Exists(revisionFile)?long.Parse(File.ReadAllText(revisionFile)):0;
        if(release.revision<previous)throw new Exception("Server offered an older release manifest. Update refused.");
        Updates.AtomicText(revisionFile,release.revision.ToString());notes.Text=release.notes;
        progress.IsIndeterminate=false;
        var reporter=new Progress<(double,string)>(v=>{progress.Value=v.Item1;status.Text=v.Item2;});
        var installed=Updates.Installed("game",channel);
        var action=Updates.ActionFor(release,Updates.Version,installed.Item1?.version);
        if(action=="launcher")
        {
            status.Text="Launcher update required first. The game update will follow after restart.";
            var exe=await Updates.Install(release.launcher,"launcher","public",config.development,reporter);
            Process.Start(new ProcessStartInfo(exe){UseShellExecute=true,Arguments="--wait "+Environment.ProcessId});Close();return;
        }
        string game;
        if(action=="game" || installed.Item1?.sha256 != release.game.sha256)game=await Updates.Install(release.game,"game",channel,config.development,reporter);
        else game=installed.Item2!;
        // Recheck immediately before issuing a one-time credential and launching.
        var fresh=await Api("/releases/"+channel);
        var latest=Updates.Verify(fresh.GetRawText(),config.publicKey,channel);
        if(latest.revision!=release.revision)throw new Exception("A new update was just published. Press Update & play again.");
        var ticket=await Api("/auth/launch-ticket",new{});
        var start=new ProcessStartInfo(game){UseShellExecute=false,WorkingDirectory=Path.GetDirectoryName(game)!};
        start.Environment["AMIIN_API"]=config.api;start.Environment["AMIIN_CHANNEL"]=channel;
        start.Environment["AMIIN_LAUNCH_TICKET"]=ticket.GetProperty("ticket").GetString();
        var pack=Path.Combine(start.WorkingDirectory,"VerdantWilds.pck");
        if(File.Exists(pack)){start.ArgumentList.Add("--main-pack");start.ArgumentList.Add(pack);}
        Process.Start(start);status.Text="Adventure launched. Host a world to get your invite code.";play.Content="Play again";
    }
}
