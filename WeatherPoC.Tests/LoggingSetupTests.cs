using AwesomeAssertions;
using Serilog;
using WeatherPoC.Core;
using Xunit;

namespace WeatherPoC.Tests;

public class LoggingSetupTests
{
    [Fact]
    public void Configured_logger_writes_the_line_to_a_dated_rolling_file_on_disk()
    {
        var baseDir = Path.Combine(Path.GetTempPath(), "weatherpoc-tests", Guid.NewGuid().ToString("N"));
        try
        {
            using (var logger = LoggingSetup.CreateConfiguration(baseDir).CreateLogger())
            {
                logger.Information("walking-skeleton startup line");
            } // dispose flushes the sink and releases the file handle

            var files = Directory.GetFiles(Path.Combine(baseDir, "logs"), "weatherpoc-*.log");
            files.Should().HaveCount(1);
            File.ReadAllText(files[0]).Should().Contain("walking-skeleton startup line");
        }
        finally
        {
            if (Directory.Exists(baseDir)) Directory.Delete(baseDir, recursive: true);
        }
    }
}
