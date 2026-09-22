using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace Amiin.Converters;

/// <summary>Converts (Value, Maximum, TrackActualWidth) into the pixel width of a progress-bar fill.</summary>
public class ProgressToWidthConverter : IMultiValueConverter
{
    public object Convert(object[] values, Type targetType, object? parameter, CultureInfo culture)
    {
        if (values.Length < 3 || values[0] is not double value || values[1] is not double maximum || values[2] is not double trackWidth)
            return 0d;
        if (maximum <= 0 || double.IsNaN(trackWidth) || trackWidth <= 0) return 0d;
        var ratio = Math.Clamp(value / maximum, 0, 1);
        return trackWidth * ratio;
    }

    public object[] ConvertBack(object value, Type[] targetTypes, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
