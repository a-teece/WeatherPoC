using System.Diagnostics.CodeAnalysis;

namespace WeatherPoC;

[ExcludeFromCodeCoverage(Justification = "Application bootstrap: untestable wiring, coverage-excluded per Overriding Principle 5.")]
public partial class App : Application
{
    private readonly MainPage _mainPage;

    public App(MainPage mainPage)
    {
        InitializeComponent();
        _mainPage = mainPage;
    }

    protected override Window CreateWindow(IActivationState? activationState)
        => new Window(_mainPage);
}
