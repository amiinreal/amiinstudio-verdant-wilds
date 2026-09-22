using System.Windows.Controls;
using Amiin.ViewModels;

namespace Amiin.Views;

public partial class LoginView : UserControl
{
    public LoginView()
    {
        InitializeComponent();
    }

    // PasswordBox.Password can't be data-bound directly (security), so it's pushed to the
    // view model on every change instead.
    private void PasswordInput_PasswordChanged(object sender, System.Windows.RoutedEventArgs e)
    {
        if (DataContext is LoginViewModel vm) vm.Password = PasswordInput.Password;
    }
}
