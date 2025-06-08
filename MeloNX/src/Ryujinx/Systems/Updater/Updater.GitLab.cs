using Gommon;
using Ryujinx.Ava.Common.Locale;
using Ryujinx.Ava.UI.Helpers;
using Ryujinx.Common;
using Ryujinx.Common.Helper;
using Ryujinx.Common.Logging;
using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Ryujinx.Ava.Systems
{
    internal static partial class Updater
    {
        private static string CreateUpdateQueryUrl()
        {
#pragma warning disable CS8524
            var os = RunningPlatform.CurrentOS switch
#pragma warning restore CS8524
            {
                OperatingSystemType.MacOS => "mac",
                OperatingSystemType.Linux => "linux",
                OperatingSystemType.Windows => "win"
            };

            var arch = RunningPlatform.Architecture switch
            {
                Architecture.Arm64 => "arm",
                Architecture.X64 => "amd64",
                _ => null
            };

            if (arch is null)
                return null;

            var rc = ReleaseInformation.IsCanaryBuild ? "canary" : "stable";

            return $"https://update.ryujinx.app/latest/query?os={os}&arch={arch}&rc={rc}";
        }

        private static async Task<Optional<(Version Current, Version Incoming)>> CheckGitLabVersionAsync(bool showVersionUpToDate = false)
        {
            if (!Version.TryParse(Program.Version, out Version currentVersion))
            {
                Logger.Error?.Print(LogClass.Application,
                    $"Failed to convert the current {RyujinxApp.FullAppName} version!");

                await ContentDialogHelper.CreateWarningDialog(
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterConvertFailedMessage],
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterCancelUpdateMessage]);

                _running = false;

                return default;
            }

            if (CreateUpdateQueryUrl() is not {} updateUrl)
            {
                Logger.Error?.Print(LogClass.Application, "Could not determine URL for updates.");
                
                _running = false;

                return default;
            }

            Logger.Info?.Print(LogClass.Application, $"Checking for updates from {updateUrl}.");

            // Get latest version number from GitLab API
            using HttpClient jsonClient = ConstructHttpClient();

            // GitLab instance is located in Ukraine. Connection times will vary across the world.
            jsonClient.Timeout = TimeSpan.FromSeconds(10);

            try
            {
                UpdaterResponse response =
                    await jsonClient.GetFromJsonAsync(updateUrl, UpdaterResponseJsonContext.Default.UpdaterResponse);

                _buildVer = response.Tag;
                _buildUrl = response.DownloadUrl;
                _changelogUrlFormat = response.ReleaseUrlFormat;
            }
            catch (Exception e)
            {
                Logger.Error?.Print(LogClass.Application, $"An error occurred when parsing JSON response from API ({e.GetType().AsFullNamePrettyString()}): {e.Message}");
                
                _running = false;
                return default;
            }

            // If build URL not found, assume no new update is available.
            if (_buildUrl is null or "")
            {
                if (showVersionUpToDate)
                {
                    UserResult userResult = await ContentDialogHelper.CreateUpdaterUpToDateInfoDialog(
                        LocaleManager.Instance[LocaleKeys.DialogUpdaterAlreadyOnLatestVersionMessage],
                        string.Empty);

                    if (userResult is UserResult.Ok)
                    {
                        OpenHelper.OpenUrl(_changelogUrlFormat.Format(currentVersion));
                    }
                }

                Logger.Info?.Print(LogClass.Application, "Up to date.");

                _running = false;

                return default;
            }


            if (!Version.TryParse(_buildVer, out Version newVersion))
            {
                Logger.Error?.Print(LogClass.Application,
                    $"Failed to convert the received {RyujinxApp.FullAppName} version from GitLab!");

                await ContentDialogHelper.CreateWarningDialog(
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterConvertFailedGithubMessage],
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterCancelUpdateMessage]);

                _running = false;

                return default;
            }

            return (currentVersion, newVersion);
        }
        
        [JsonSerializable(typeof(UpdaterResponse))]
        partial class UpdaterResponseJsonContext : JsonSerializerContext;

        public class UpdaterResponse
        {
            [JsonPropertyName("tag")] public string Tag { get; set; }
            [JsonPropertyName("download_url")] public string DownloadUrl { get; set; }
            [JsonPropertyName("web_url")] public string ReleaseUrl { get; set; }

            [JsonIgnore] public string ReleaseUrlFormat => ReleaseUrl.Replace(Tag, "{0}");
        }
    }
}
