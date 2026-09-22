using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Amiin.Models;
using Amiin.ViewModels;

namespace Amiin.Views;

public partial class LibraryView : UserControl
{
    public LibraryView()
    {
        InitializeComponent();
    }

    // Border.ClipToBounds only clips to the rectangular bounds, not the rounded corners of
    // its own content -- the hero artwork needs an explicit rounded clip to match CornerRadius.
    private void HeroBorder_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        var border = (Border)sender;
        border.Clip = new RectangleGeometry(new Rect(0, 0, e.NewSize.Width, e.NewSize.Height), 16, 16);
    }

    private void Hero_Click(object sender, MouseButtonEventArgs e)
    {
        if (DataContext is LibraryViewModel vm && ((FrameworkElement)sender).DataContext is GameModel game)
            vm.OpenGameCommand.Execute(game);
    }

    private void Card_Click(object sender, MouseButtonEventArgs e)
    {
        if (DataContext is LibraryViewModel vm && ((FrameworkElement)sender).DataContext is GameModel game)
            vm.OpenGameCommand.Execute(game);
    }
}
