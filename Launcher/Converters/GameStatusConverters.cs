using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using Amiin.Models;

namespace Amiin.Converters;

public class NotInstalledToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is GameStatus.NotInstalled ? Visibility.Visible : Visibility.Collapsed;

    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture) => throw new NotSupportedException();
}

public class InstalledToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is GameStatus.NotInstalled ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture) => throw new NotSupportedException();
}

/// <summary>Ready = faint grey, Update available = green, Not installed = grey.</summary>
public class GameStatusColorConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) => value switch
    {
        GameStatus.UpdateAvailable => new SolidColorBrush((Color)ColorConverter.ConvertFromString("#3FAE58")!),
        GameStatus.NotInstalled => new SolidColorBrush((Color)ColorConverter.ConvertFromString("#9AA0AC")!),
        _ => new SolidColorBrush((Color)ColorConverter.ConvertFromString("#666C78")!)
    };

    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture) => throw new NotSupportedException();
}
