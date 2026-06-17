using Serilog;

namespace WeatherPoC.Core;

/// <summary>
/// Serilog rolling-file configuration for WeatherPoC, factored out of the app
/// shell so the on-disk write contract (Seam 4) is testable with real I/O. The
/// platform-bound per-user path (FileSystem.AppDataDirectory) is resolved by the
/// app head and passed in as <paramref name="baseDirectory"/>, keeping
/// WeatherPoC.Core free of MAUI/Windows dependencies (macOS-viable).
/// </summary>
public static class LoggingSetup
{
    /// <summary>
    /// Builds a Serilog configuration with a daily rolling file sink at
    /// <c>{baseDirectory}/logs/weatherpoc-.log</c> (Serilog inserts the date,
    /// yielding <c>weatherpoc-yyyyMMdd.log</c>), retaining 7 files, minimum
    /// level Information.
    /// </summary>
    public static LoggerConfiguration CreateConfiguration(string baseDirectory)
    {
        ArgumentNullException.ThrowIfNull(baseDirectory);

        var logPath = Path.Combine(baseDirectory, "logs", "weatherpoc-.log");

        return new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.File(
                path: logPath,
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 7);
    }
}
