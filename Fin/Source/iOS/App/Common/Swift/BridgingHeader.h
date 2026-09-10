// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "DOLConfigBridge.h"
#import "DOLMappingBridge.h"
#import "DOLGeckoBridge.h"
#import "AudioSessionManager.h"
#import "FastmemManager.h"
#import "BootNoticeManager.h"
#import "DolphinCoreService.h"
#import "EmulationCoordinator.h"
#import "EmulationBootParameter.h"
#import "FirstRunInitializationService.h"
#import "GameFileCacheManager.h"
#import "GameFilePtrWrapper.h"
#import "ImportFileManager.h"
#import "NandImporterHelper.h"
#import "SoftwarePropertiesViewController.h"
#import "WiiSystemUpdateViewController.h"
#import "LegacyInputConfigMigrationService.h"
#import "MainSceneCoordinator.h"
#import "UpdateNoticeViewController.h"
#import "UpdateRequiredNoticeViewController.h"

#if TARGET_OS_IOS
#import "DOLUIKitSwitch.h"
#import "TCManagerInterface.h"
#endif
