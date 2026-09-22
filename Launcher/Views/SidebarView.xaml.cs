using System.Windows;
using System.Windows.Controls;
using Amiin.Services;

namespace Amiin.Views;

public partial class SidebarView : UserControl
{
    public static readonly DependencyProperty ActiveRouteProperty = DependencyProperty.Register(
        nameof(ActiveRoute), typeof(string), typeof(SidebarView), new PropertyMetadata("Library", OnActiveRouteChanged));

    public string ActiveRoute
    {
        get => (string)GetValue(ActiveRouteProperty);
        set => SetValue(ActiveRouteProperty, value);
    }

    public SidebarView()
    {
        InitializeComponent();
        Loaded += (_, _) =>
        {
            var state = AppState.Current;
            if (state is null) return;
            UserNameText.Text = string.IsNullOrEmpty(state.Username) ? "Explorer" : state.Username;
            AvatarInitial.Text = string.IsNullOrEmpty(state.Username) ? "A" : state.Username[..1].ToUpperInvariant();
            ApplyActiveRoute();
        };
        NavLibrary.Checked += (_, _) => Navigate("Library");
    }

    private static void OnActiveRouteChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) =>
        ((SidebarView)d).ApplyActiveRoute();

    private void ApplyActiveRoute()
    {
        var target = ActiveRoute switch
        {
            "Store" => NavStore,
            "Downloads" => NavDownloads,
            "Friends" => NavFriends,
            "Settings" => NavSettings,
            _ => NavLibrary
        };
        if (target.IsChecked != true) target.IsChecked = true;
    }

    private void Navigate(string route)
    {
        if (route == "Library" && AppState.Current is not null)
            AppState.Current.Navigation?.NavigateToLibrary();
    }
}
