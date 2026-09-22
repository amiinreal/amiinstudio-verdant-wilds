using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace Amiin.Converters;

/// <summary>Returns Visible when the bound value's runtime type name matches the parameter
/// (comma-separated for "any of"), Collapsed otherwise. Used to toggle full-window overlays
/// (Login / Status) based on which ViewModel is currently active.</summary>
public class TypeMatchConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is null || parameter is not string names) return Visibility.Collapsed;
        var typeName = value.GetType().Name;
        var wanted = names.Split(',', StringSplitOptions.TrimEntries);
        return wanted.Contains(typeName) ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

public class InverseTypeMatchConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is null || parameter is not string names) return Visibility.Visible;
        var typeName = value.GetType().Name;
        var wanted = names.Split(',', StringSplitOptions.TrimEntries);
        return wanted.Contains(typeName) ? Visibility.Collapsed : Visibility.Visible;
    }

    public object ConvertBack(object value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
