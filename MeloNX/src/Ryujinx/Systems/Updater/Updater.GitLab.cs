using Gommon;
using Ryujinx.Ava.Common.Locale;
using Ryujinx.Ava.Common.Models.GitLab;
using Ryujinx.Ava.UI.Helpers;
using Ryujinx.Common;
using Ryujinx.Common.Helper;
using Ryujinx.Common.Logging;
using Ryujinx.Common.Utilities;
using System;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Ryujinx.Ava.Systems
{
    internal static partial class Updater
    {
        private static GitLabReleaseChannels.ChannelType _currentGitLabReleaseChannel;

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

            Logger.Info?.Print(LogClass.Application, "Checking for updates from https://git.ryujinx.app.");

            // Get latest version number from GitLab API
            using HttpClient jsonClient = ConstructHttpClient();

            // GitLab instance is located in Ukraine. Connection times will vary across the world.
            jsonClient.Timeout = TimeSpan.FromSeconds(10); 

            if (_currentGitLabReleaseChannel == null)
            {
                GitLabReleaseChannels releaseChannels = await GitLabReleaseChannels.GetAsync(jsonClient);

                _currentGitLabReleaseChannel = ReleaseInformation.IsCanaryBuild
                    ? releaseChannels.Canary
                    : releaseChannels.Stable;
                
                Logger.Info?.Print(LogClass.Application, $"Loaded GitLab release channel for '{(ReleaseInformation.IsCanaryBuild ? "canary" : "stable")}'");

                _changelogUrlFormat = _currentGitLabReleaseChannel.UrlFormat;
            }

            string fetchedJson = await jsonClient.GetStringAsync(_currentGitLabReleaseChannel.GetLatestReleaseApiUrl());
            GitLabReleasesJsonResponse fetched = JsonHelper.Deserialize(fetchedJson, _glSerializerContext.GitLabReleasesJsonResponse);

            _buildVer = fetched.TagName;
            _buildUrl = fetched.Assets.Links
                .FirstOrDefault(link =>
                    link.AssetName.StartsWith("ryujinx") && link.AssetName.EndsWith(_platformExt)
                )?.Url;

            // If build URL not found, assume no new update are available.
            if (_buildUrl is null)
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

        [JsonSerializable(typeof(GitLabReleaseChannels))]
        partial class GitLabReleaseChannelPairContext : JsonSerializerContext;

        public class GitLabReleaseChannels
        {
            public static async Task<GitLabReleaseChannels> GetAsync(HttpClient httpClient)
                => await httpClient.GetFromJsonAsync(
                    "https://git.ryujinx.app/ryubing/ryujinx/-/snippets/1/raw/main/meta.json",
                    GitLabReleaseChannelPairContext.Default.GitLabReleaseChannels);

            [JsonPropertyName("stable")] public ChannelType Stable { get; set; }
            [JsonPropertyName("canary")] public ChannelType Canary { get; set; }

            public class ChannelType
            {
                [JsonPropertyName("id")] public long Id { get; set; }

                [JsonPropertyName("group")] public string Group { get; set; }

                [JsonPropertyName("project")] public string Project { get; set; }

                public string UrlFormat => $"https://git.ryujinx.app/{ToString()}/-/releases/{{0}}";

                public override string ToString() => $"{Group}/{Project}";

                public string GetLatestReleaseApiUrl() =>
                    $"https://git.ryujinx.app/api/v4/{Id}/releases/permalink/latest";
            }
        }
    }
}
