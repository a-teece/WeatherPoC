using System.Diagnostics.CodeAnalysis;
using Microsoft.Extensions.Logging;
using Serilog;
using Serilog.Extensions.Logging;
using WeatherPoC.Core;

namespace WeatherPoC;

[ExcludeFromCodeCoverage(Justification = "DI composition root + Serilog bootstrap: untestable wiring, coverage-excluded per Overriding Principle 5.")]
public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        // The rolling-file configuration (path + sink) is the testable Seam 4 contract in
        // WeatherPoC.Core; the app head passes the platform-bound per-user path into it.
        var loggerConfiguration = LoggingSetup.CreateConfiguration(FileSystem.AppDataDirectory);

#if DEBUG
        loggerConfiguration = loggerConfiguration.WriteTo.Debug();
#endif

        Log.Logger = loggerConfiguration.CreateLogger();

        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
            });

        builder.Logging.ClearProviders();
        builder.Logging.AddSerilog(Log.Logger, dispose: true);

        builder.Services.AddSingleton<MainPage>();

        return builder.Build();
    }
}
