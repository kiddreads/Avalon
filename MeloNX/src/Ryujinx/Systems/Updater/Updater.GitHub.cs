using Gommon;
using Ryujinx.Ava.Common.Locale;
using Ryujinx.Ava.Common.Models.Github;
using Ryujinx.Ava.UI.Helpers;
using Ryujinx.Common;
using Ryujinx.Common.Helper;
using Ryujinx.Common.Logging;
using Ryujinx.Common.Utilities;
using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Ryujinx.Ava.Systems
{
    internal static partial class Updater
    {
        private static GitHubReleaseChannels.Channel? _currentGitHubReleaseChannel;
        
        private static async Task<Optional<(Version Current, Version Incoming)>> CheckGitHubVersionAsync(bool showVersionUpToDate = false)
        {
            if (!Version.TryParse(Program.Version, out Version currentVersion))
            {
                Logger.Error?.Print(LogClass.Application, $"Failed to convert the current {RyujinxApp.FullAppName} version!");

                await ContentDialogHelper.CreateWarningDialog(
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterConvertFailedMessage],
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterCancelUpdateMessage]);

                _running = false;

                return default;
            }

            Logger.Info?.Print(LogClass.Application, "Checking for updates from GitHub.");

            // Get latest version number from GitHub API
            try
            {
                using HttpClient jsonClient = ConstructHttpClient();

                if (_currentGitHubReleaseChannel == null)
                {
                    GitHubReleaseChannels releaseChannels = await GitHubReleaseChannels.GetAsync(jsonClient);

                    _currentGitHubReleaseChannel = ReleaseInformation.IsCanaryBuild
                        ? releaseChannels.Canary
                        : releaseChannels.Stable;
                    
                    Logger.Info?.Print(LogClass.Application, $"Loaded GitHub release channel for '{(ReleaseInformation.IsCanaryBuild ? "canary" : "stable")}'");

                    _changelogUrlFormat = _currentGitHubReleaseChannel.Value.UrlFormat;
                }

                string fetchedJson = await jsonClient.GetStringAsync(_currentGitHubReleaseChannel.Value.GetLatestReleaseApiUrl());
                GithubReleasesJsonResponse fetched = JsonHelper.Deserialize(fetchedJson, _ghSerializerContext.GithubReleasesJsonResponse);
                _buildVer = fetched.TagName;

                foreach (GithubReleaseAssetJsonResponse asset in fetched.Assets)
                {
                    if (asset.Name.StartsWith("ryujinx") && asset.Name.EndsWith(_platformExt))
                    {
                        _buildUrl = asset.BrowserDownloadUrl;

                        if (asset.State != "uploaded")
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

                        break;
                    }
                }

                // If build not done, assume no new update are available.
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
            }
            catch (Exception exception)
            {
                Logger.Error?.Print(LogClass.Application, exception.Message);

                await ContentDialogHelper.CreateErrorDialog(
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterFailedToGetVersionMessage]);

                _running = false;

                return default;
            }

            if (!Version.TryParse(_buildVer, out Version newVersion))
            {
                Logger.Error?.Print(LogClass.Application, $"Failed to convert the received {RyujinxApp.FullAppName} version from GitHub!");

                await ContentDialogHelper.CreateWarningDialog(
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterConvertFailedGithubMessage],
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterCancelUpdateMessage]);

                _running = false;

                return default;
            }

            return (currentVersion, newVersion);
        }
    }
    
    public readonly struct GitHubReleaseChannels
    {
        public static async Task<GitHubReleaseChannels> GetAsync(HttpClient httpClient)
        {
            ReleaseChannelPair releaseChannelPair = await httpClient.GetFromJsonAsync("https://ryujinx.app/api/release-channels", ReleaseChannelPairContext.Default.ReleaseChannelPair);
            return new GitHubReleaseChannels(releaseChannelPair);
        }
        
        internal GitHubReleaseChannels(ReleaseChannelPair channelPair)
        {
            Stable = new Channel(channelPair.Stable);
            Canary = new Channel(channelPair.Canary);
        }

        public readonly Channel Stable;
        public readonly Channel Canary;

        public readonly struct Channel
        {
            public Channel(string raw)
            {
                string[] parts = raw.Split('/');
                Owner = parts[0];
                Repo = parts[1];
            }

            public readonly string Owner;
            public readonly string Repo;

            public string UrlFormat => $"https://github.com/{ToString()}/releases/{{0}}";

            public override string ToString() => $"{Owner}/{Repo}";

            public string GetLatestReleaseApiUrl() =>
                $"https://api.github.com/repos/{ToString()}/releases/latest";
        }
    }

    [JsonSerializable(typeof(ReleaseChannelPair))]
    partial class ReleaseChannelPairContext : JsonSerializerContext;

    class ReleaseChannelPair
    {
        [JsonPropertyName("stable")]
        public string Stable { get; set; }
        [JsonPropertyName("canary")]
        public string Canary { get; set; }
    }
}
