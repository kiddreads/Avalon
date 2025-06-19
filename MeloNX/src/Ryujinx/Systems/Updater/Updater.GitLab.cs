using Gommon;
using Ryujinx.Ava.Common.Locale;
using Ryujinx.Ava.UI.Helpers;
using Ryujinx.Common;
using Ryujinx.Common.Helper;
using Ryujinx.Common.Logging;
using Ryujinx.Systems.Update.Client;
using Ryujinx.Systems.Update.Common;
using System;
using System.Threading.Tasks;

namespace Ryujinx.Ava.Systems
{
    internal static partial class Updater
    {
        private static VersionResponse _versionResponse;

        private static UpdateClient CreateUpdateClient()
            => UpdateClient.Builder()
                .WithServerEndpoint("https://update.ryujinx.app") // This is the default, and doesn't need to be provided; it's here for transparency.
                .WithLogger((format, args, caller) => 
                    Logger.Info?.Print(
                        LogClass.Application, 
                        args.Length is 0 ? format : format.Format(args), 
                        caller: caller)
                    );

        public static async Task<Optional<(Version Current, Version Incoming)>> CheckVersionAsync(bool showVersionUpToDate = false)
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

            using UpdateClient updateClient = CreateUpdateClient();

            try
            {
                _versionResponse = await updateClient.QueryLatestAsync(ReleaseInformation.IsCanaryBuild
                    ? ReleaseChannel.Canary
                    : ReleaseChannel.Stable);
            }
            catch (Exception e)
            {
                Logger.Error?.Print(LogClass.Application, $"An error occurred when requesting for updates ({e.GetType().AsFullNamePrettyString()}): {e.Message}");

                _running = false;
                return default;
            }
            
            if (_versionResponse == null)
            {
                // logging is done via the UpdateClient library
                _running = false;
                return default;
            }

            // If build URL not found, assume no new update is available.
            if (_versionResponse.ArtifactUrl is null or "")
            {
                if (showVersionUpToDate)
                {
                    UserResult userResult = await ContentDialogHelper.CreateUpdaterUpToDateInfoDialog(
                        LocaleManager.Instance[LocaleKeys.DialogUpdaterAlreadyOnLatestVersionMessage],
                        string.Empty);

                    if (userResult is UserResult.Ok)
                    {
                        OpenHelper.OpenUrl(_versionResponse.ReleaseUrlFormat.Format(currentVersion));
                    }
                }

                Logger.Info?.Print(LogClass.Application, "Up to date.");

                _running = false;

                return default;
            }


            if (!Version.TryParse(_versionResponse.Version, out Version newVersion))
            {
                Logger.Error?.Print(LogClass.Application,
                    $"Failed to convert the received {RyujinxApp.FullAppName} version from the update server!");

                await ContentDialogHelper.CreateWarningDialog(
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterConvertFailedServerMessage],
                    LocaleManager.Instance[LocaleKeys.DialogUpdaterCancelUpdateMessage]);

                _running = false;

                return default;
            }

            return (currentVersion, newVersion);
        }
    }
}
