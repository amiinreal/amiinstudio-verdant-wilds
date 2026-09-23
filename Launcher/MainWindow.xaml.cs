using System.Windows;
using Amiin.Services;

namespace Amiin;

public partial class MainWindow : Window
{
    public MainWindow(NavigationService navigation)
    {
        DataContext = navigation;
        InitializeComponent();
        navigation.RequestCloseApplication = Close;
    }

    private void Minimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;

    private void Maximize_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;

    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
