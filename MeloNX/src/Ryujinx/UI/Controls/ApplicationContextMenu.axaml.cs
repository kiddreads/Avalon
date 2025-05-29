using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using Avalonia.Platform.Storage;
using CommunityToolkit.Mvvm.Input;
using LibHac.Fs;
using LibHac.Tools.FsSystem.NcaUtils;
using Ryujinx.Ava.Common;
using Ryujinx.Ava.Common.Locale;
using Ryujinx.Ava.Common.Models;
using Ryujinx.Ava.UI.Helpers;
using Ryujinx.Ava.UI.ViewModels;
using Ryujinx.Ava.UI.Windows;
using Ryujinx.Ava.Utilities;
using Ryujinx.Ava.Systems.AppLibrary;
using Ryujinx.Ava.UI.Views.Dialog;
using Ryujinx.Common.Configuration;
using Ryujinx.Common.Helper;
using Ryujinx.HLE.HOS;
using SkiaSharp;
using System;
using System.Collections.Generic;
using System.IO;
using Path = System.IO.Path;

namespace Ryujinx.Ava.UI.Controls
{
    public class ApplicationContextMenu : MenuFlyout
    {
        public ApplicationContextMenu()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            AvaloniaXamlLoader.Load(this);
        }
        
        public static RelayCommand<MainWindowViewModel> ToggleFavorite { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null,
                viewModel =>
                {
                    viewModel.SelectedApplication.Favorite = !viewModel.SelectedApplication.Favorite;

                    ApplicationLibrary.LoadAndSaveMetaData(viewModel.SelectedApplication.IdString, appMetadata =>
                    {
                        appMetadata.Favorite = viewModel.SelectedApplication.Favorite;
                    });

                    viewModel.RefreshView();
                }
            );
        
        public static RelayCommand<MainWindowViewModel> OpenUserSaveDirectory { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel =>
                    OpenSaveDirectory(viewModel, SaveDataType.Account, new UserId((ulong)viewModel.AccountManager.LastOpenedUser.UserId.High, (ulong)viewModel.AccountManager.LastOpenedUser.UserId.Low))
                );
        
        public static RelayCommand<MainWindowViewModel> OpenDeviceSaveDirectory { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null,
                viewModel => OpenSaveDirectory(viewModel, SaveDataType.Device, default));
        
        public static RelayCommand<MainWindowViewModel> OpenBcatSaveDirectory { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => OpenSaveDirectory(viewModel, SaveDataType.Bcat, default));

        private static void OpenSaveDirectory(MainWindowViewModel viewModel, SaveDataType saveDataType, UserId userId)
        {
            SaveDataFilter saveDataFilter = SaveDataFilter.Make(viewModel.SelectedApplication.Id, saveDataType, userId, saveDataId: default, index: default);

            ApplicationHelper.OpenSaveDir(in saveDataFilter, viewModel.SelectedApplication.Id, viewModel.SelectedApplication.ControlHolder, viewModel.SelectedApplication.Name);
        }
        
        public static AsyncRelayCommand<MainWindowViewModel> OpenTitleUpdateManager { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => TitleUpdateManagerView.Show(viewModel.ApplicationLibrary, viewModel.SelectedApplication)
            );
        
        public static AsyncRelayCommand<MainWindowViewModel> OpenDownloadableContentManager { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => DownloadableContentManagerView.Show(viewModel.ApplicationLibrary, viewModel.SelectedApplication)
            );
        
        public static AsyncRelayCommand<MainWindowViewModel> OpenCheatManager { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => StyleableAppWindow.ShowAsync(
                    new CheatWindow(
                        viewModel.VirtualFileSystem,
                        viewModel.SelectedApplication.IdString,
                        viewModel.SelectedApplication.Name,
                        viewModel.SelectedApplication.Path
                    )
                ));
        
        public static RelayCommand<MainWindowViewModel> OpenModsDirectory { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel =>
                {
                    string modsBasePath = ModLoader.GetModsBasePath();
                    string titleModsPath = ModLoader.GetApplicationDir(modsBasePath, viewModel.SelectedApplication.IdString);

                    OpenHelper.OpenFolder(titleModsPath);
                });
        
        public static RelayCommand<MainWindowViewModel> OpenSdModsDirectory { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel =>
            {
                string sdModsBasePath = ModLoader.GetSdModsBasePath();
                string titleModsPath = ModLoader.GetApplicationDir(sdModsBasePath, viewModel.SelectedApplication.IdString);

                OpenHelper.OpenFolder(titleModsPath);
            });

        public static AsyncRelayCommand<MainWindowViewModel> OpenModManager { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
            {
                await ModManagerView.Show(
                    viewModel.SelectedApplication.Id,
                    viewModel.SelectedApplication.IdBase,
                    viewModel.ApplicationLibrary,
                    viewModel.SelectedApplication.Name);
            });
        
        public static AsyncRelayCommand<MainWindowViewModel> PurgePtcCache { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
            {
                UserResult result = await ContentDialogHelper.CreateLocalizedConfirmationDialog(
                    LocaleManager.Instance[LocaleKeys.DialogWarning],
                    LocaleManager.Instance.UpdateAndGetDynamicValue(LocaleKeys.DialogPPTCDeletionMessage, viewModel.SelectedApplication.Name)
                );

                if (result == UserResult.Yes)
                {
                    DirectoryInfo mainDir = new(Path.Combine(AppDataManager.GamesDirPath, viewModel.SelectedApplication.IdString, "cache", "cpu", "0"));
                    DirectoryInfo backupDir = new(Path.Combine(AppDataManager.GamesDirPath, viewModel.SelectedApplication.IdString, "cache", "cpu", "1"));

                    List<FileInfo> cacheFiles = [];

                    if (mainDir.Exists)
                    {
                        cacheFiles.AddRange(mainDir.EnumerateFiles("*.cache"));
                    }

                    if (backupDir.Exists)
                    {
                        cacheFiles.AddRange(backupDir.EnumerateFiles("*.cache"));
                    }

                    if (cacheFiles.Count > 0)
                    {
                        foreach (FileInfo file in cacheFiles)
                        {
                            try
                            {
                                file.Delete();
                            }
                            catch (Exception ex)
                            {
                                await ContentDialogHelper.CreateErrorDialog(LocaleManager.Instance.UpdateAndGetDynamicValue(LocaleKeys.DialogPPTCDeletionErrorMessage, file.Name, ex));
                            }
                        }
                    }
                }
            });
        
        public static AsyncRelayCommand<MainWindowViewModel> NukePtcCache { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
            {
                UserResult result = await ContentDialogHelper.CreateLocalizedConfirmationDialog(
                    LocaleManager.Instance[LocaleKeys.DialogWarning],
                    LocaleManager.Instance.UpdateAndGetDynamicValue(LocaleKeys.DialogPPTCNukeMessage, viewModel.SelectedApplication.Name)
                );

                if (result == UserResult.Yes)
                {
                    DirectoryInfo mainDir = new(Path.Combine(AppDataManager.GamesDirPath, viewModel.SelectedApplication.IdString, "cache", "cpu", "0"));
                    DirectoryInfo backupDir = new(Path.Combine(AppDataManager.GamesDirPath, viewModel.SelectedApplication.IdString, "cache", "cpu", "1"));

                    List<FileInfo> cacheFiles = [];

                    if (mainDir.Exists)
                    {
                        cacheFiles.AddRange(mainDir.EnumerateFiles("*.cache"));
                        cacheFiles.AddRange(mainDir.EnumerateFiles("*.info"));
                    }

                    if (backupDir.Exists)
                    {
                        cacheFiles.AddRange(backupDir.EnumerateFiles("*.cache"));
                        cacheFiles.AddRange(backupDir.EnumerateFiles("*.info"));
                    }

                    if (cacheFiles.Count > 0)
                    {
                        foreach (FileInfo file in cacheFiles)
                        {
                            try
                            {
                                file.Delete();
                            }
                            catch (Exception ex)
                            {
                                await ContentDialogHelper.CreateErrorDialog(LocaleManager.Instance.UpdateAndGetDynamicValue(LocaleKeys.DialogPPTCDeletionErrorMessage, file.Name, ex));
                            }
                        }
                    }
                }
            });
        
        public static AsyncRelayCommand<MainWindowViewModel> PurgeShaderCache { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
            {
            UserResult result = await ContentDialogHelper.CreateLocalizedConfirmationDialog(
                LocaleManager.Instance[LocaleKeys.DialogWarning],
                LocaleManager.Instance.UpdateAndGetDynamicValue(LocaleKeys.DialogShaderDeletionMessage, viewModel.SelectedApplication.Name)
            );

            if (result == UserResult.Yes)
            {
                DirectoryInfo shaderCacheDir = new(Path.Combine(AppDataManager.GamesDirPath, viewModel.SelectedApplication.IdString, "cache", "shader"));

                List<DirectoryInfo> oldCacheDirectories = [];
                List<FileInfo> newCacheFiles = [];

                if (shaderCacheDir.Exists)
                {
                    oldCacheDirectories.AddRange(shaderCacheDir.EnumerateDirectories("*"));
                    newCacheFiles.AddRange(shaderCacheDir.GetFiles("*.toc"));
                    newCacheFiles.AddRange(shaderCacheDir.GetFiles("*.data"));
                }

                if ((oldCacheDirectories.Count > 0 || newCacheFiles.Count > 0))
                {
                    foreach (DirectoryInfo directory in oldCacheDirectories)
                    {
                        try
                        {
                            directory.Delete(true);
                        }
                        catch (Exception ex)
                        {
                            await ContentDialogHelper.CreateErrorDialog(LocaleManager.Instance.UpdateAndGetDynamicValue(LocaleKeys.DialogPPTCDeletionErrorMessage, directory.Name, ex));
                        }
                    }

                    foreach (FileInfo file in newCacheFiles)
                    {
                        try
                        {
                            file.Delete();
                        }
                        catch (Exception ex)
                        {
                            await ContentDialogHelper.CreateErrorDialog(LocaleManager.Instance.UpdateAndGetDynamicValue(LocaleKeys.ShaderCachePurgeError, file.Name, ex));
                        }
                    }
                }
            } 
            });
        
        public static RelayCommand<MainWindowViewModel> OpenPtcDirectory { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel =>
            {
                string ptcDir = Path.Combine(AppDataManager.GamesDirPath, viewModel.SelectedApplication.IdString, "cache", "cpu");
                string mainDir = Path.Combine(ptcDir, "0");
                string backupDir = Path.Combine(ptcDir, "1");

                if (!Directory.Exists(ptcDir))
                {
                    Directory.CreateDirectory(ptcDir);
                    Directory.CreateDirectory(mainDir);
                    Directory.CreateDirectory(backupDir);
                }

                OpenHelper.OpenFolder(ptcDir);
            });
        
        public static RelayCommand<MainWindowViewModel> OpenShaderCacheDirectory { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel =>
                {
                    string shaderCacheDir = Path.Combine(AppDataManager.GamesDirPath, viewModel.SelectedApplication.IdString.ToLower(), "cache", "shader");

                    if (!Directory.Exists(shaderCacheDir))
                    {
                        Directory.CreateDirectory(shaderCacheDir);
                    }

                    OpenHelper.OpenFolder(shaderCacheDir);
                });
        
        public static AsyncRelayCommand<MainWindowViewModel> ExtractApplicationExeFs { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
                {
                    await ApplicationHelper.ExtractSection(
                        viewModel.StorageProvider,
                        NcaSectionType.Code,
                        viewModel.SelectedApplication.Path,
                        viewModel.SelectedApplication.Name);
                });
        
        public static AsyncRelayCommand<MainWindowViewModel> ExtractApplicationRomFs { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
                {
                    await ApplicationHelper.ExtractSection(
                        viewModel.StorageProvider,
                        NcaSectionType.Data,
                        viewModel.SelectedApplication.Path,
                        viewModel.SelectedApplication.Name);
                });
        
        public static AsyncRelayCommand<MainWindowViewModel> ExtractApplicationAocRomFs { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
                {
                    DownloadableContentModel selectedDlc = await DlcSelectView.Show(viewModel.SelectedApplication.Id, viewModel.ApplicationLibrary);
            
                    if (selectedDlc is not null)
                    {
                        await ApplicationHelper.ExtractAoc(
                            viewModel.StorageProvider,
                            selectedDlc.ContainerPath,
                            selectedDlc.FileName);
                    }
                });
        
        public static AsyncRelayCommand<MainWindowViewModel> ExtractApplicationLogo { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
                {
                    IReadOnlyList<IStorageFolder> result = await viewModel.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
                    {
                        Title = LocaleManager.Instance[LocaleKeys.FolderDialogExtractTitle],
                        AllowMultiple = false,
                    });

                    if (result.Count == 0)
                        return;

                    ApplicationHelper.ExtractSection(
                        result[0].Path.LocalPath,
                        NcaSectionType.Logo,
                        viewModel.SelectedApplication.Path,
                        viewModel.SelectedApplication.Name);

                    IStorageFile iconFile = await result[0].CreateFileAsync($"{viewModel.SelectedApplication.IdString}.png");
                    await using Stream fileStream = await iconFile.OpenWriteAsync();

                    using SKBitmap bitmap = SKBitmap.Decode(viewModel.SelectedApplication.Icon)
                        .Resize(new SKSizeI(512, 512), SKFilterQuality.High);

                    using SKData png = bitmap.Encode(SKEncodedImageFormat.Png, 100);

                    png.SaveTo(fileStream);
                });
        
        public static RelayCommand<MainWindowViewModel> CreateApplicationShortcut { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => ShortcutHelper.CreateAppShortcut(
                    viewModel.SelectedApplication.Path,
                    viewModel.SelectedApplication.Name,
                    viewModel.SelectedApplication.IdString,
                    viewModel.SelectedApplication.Icon
                ));
        
        public static AsyncRelayCommand<MainWindowViewModel> EditGameConfiguration { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                async viewModel =>
                {
                    await StyleableAppWindow.ShowAsync(new GameSpecificSettingsWindow(viewModel));

                    // just checking for file presence
                    viewModel.SelectedApplication.HasIndependentConfiguration = File.Exists(Program.GetDirGameUserConfig(viewModel.SelectedApplication.IdString,false,false));

                    viewModel.RefreshView();
                });
        
        public static AsyncRelayCommand<MainWindowViewModel> OpenApplicationCompatibility { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => CompatibilityListWindow.Show(viewModel.SelectedApplication.IdString));
        
        public static AsyncRelayCommand<MainWindowViewModel> OpenApplicationData { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => ApplicationDataView.Show(viewModel.SelectedApplication));
        
        public static AsyncRelayCommand<MainWindowViewModel> RunApplication { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => viewModel.LoadApplication(viewModel.SelectedApplication));
        
        public static AsyncRelayCommand<MainWindowViewModel> TrimXci { get; } =
            Commands.CreateConditional<MainWindowViewModel>(vm => vm?.SelectedApplication != null, 
                viewModel => viewModel.TrimXCIFile(viewModel.SelectedApplication.Path));
    }
}
