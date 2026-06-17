using System.Diagnostics.CodeAnalysis;
using Microsoft.Extensions.Logging;

namespace WeatherPoC;

[ExcludeFromCodeCoverage(Justification = "XAML View code-behind: untestable UI, coverage-excluded per Overriding Principle 5.")]
public partial class MainPage : ContentPage
{
    public MainPage(ILogger<MainPage> logger)
    {
        InitializeComponent();
        logger.LogInformation("WeatherPoC started: walking skeleton MainPage composed and rendered.");
    }
}
