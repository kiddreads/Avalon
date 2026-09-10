// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "DolphinCoreService.h"

#import "Core/Config/UISettings.h"
#import "Core/Config/MainSettings.h"
#import "Core/Config/GraphicsSettings.h"
#import "Core/Core.h"
#import "Core/DolphinAnalytics.h"
#import "Core/HW/GCPad.h"
#import "Core/HW/Wiimote.h"
#import "Core/System.h"

#import "Common/FileUtil.h"
#import "Common/Logging/LogManager.h"
#import "Common/MsgHandler.h"

#include <unistd.h>

#import "InputCommon/ControllerInterface/ControllerInterface.h"
#import "InputCommon/InputConfig.h"

#import "UICommon/UICommon.h"

#import "Fin-Swift.h"
#import "EmulationCoordinator.h"
#import "FastmemManager.h"
#import "FoundationStringUtil.h"
#import "HostQueue.h"
#import "LocalizationUtil.h"
#import "MsgAlertManager.h"

@implementation DolphinCoreService

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id>*)launchOptions {
  Core::DeclareAsHostThread();
  
  UICommon::SetUserDirectory(FoundationToCppString([UserFolderUtil getUserFolder]));
  UICommon::CreateDirectories();

#ifdef DEBUG
  NSURL* loggerIniPath = [[NSBundle mainBundle] URLForResource:@"Logger" withExtension:@"ini"];
  std::string loggerIniCppPath = FoundationToCppString([loggerIniPath path]);
  std::string destPath = File::GetUserPath(F_LOGGERCONFIG_IDX);
  
  File::Delete(File::GetUserPath(F_LOGGERCONFIG_IDX));
  File::Copy(loggerIniCppPath, File::GetUserPath(F_LOGGERCONFIG_IDX));
#endif
  
  UICommon::Init();
  
  // Suppress logging if the user disabled it in Extra settings
  // Key defaults to YES (enabled). Only suppress when explicitly set to NO.
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:@"fin.loggingEnabled"] && ![defaults boolForKey:@"fin.loggingEnabled"]) {
    auto* logManager = Common::Log::LogManager::GetInstance();
    if (logManager) {
      logManager->SetLogLevel(Common::Log::LogLevel::LERROR);
      logManager->EnableListener(Common::Log::LogListener::FILE_LISTENER, false);
      logManager->EnableListener(Common::Log::LogListener::CONSOLE_LISTENER, false);
      logManager->EnableListener(Common::Log::LogListener::LOG_WINDOW_LISTENER, false);
    }
    // Redirect stderr to /dev/null to suppress any remaining console output
    int devNull = open("/dev/null", O_WRONLY);
    if (devNull != -1) {
      dup2(devNull, STDERR_FILENO);
      close(devNull);
    }
  }
  
  [[MsgAlertManager shared] registerHandler];
  
  Common::RegisterStringTranslator([](const char* text) {
    return FoundationToCppString(DOLCoreLocalizedString(CToFoundationString(text)));
  });
  
  Config::SetBase(Config::MAIN_USE_GAME_COVERS, true);
  
  const bool fastmemAvailable = [FastmemManager shared].fastmemAvailable;
  Config::SetBase(Config::MAIN_FASTMEM, fastmemAvailable);
  Config::SetBase(Config::MAIN_FASTMEM_ARENA, fastmemAvailable);
  
  WindowSystemInfo wsi;
  wsi.type = WindowSystemType::iOS;
  
  UICommon::InitControllers(wsi);
  
  // This technically doesn't send any reports since we disabled analytics...
  // However, it initializes DolphinAnalytics, which we need to do before starting any Wii games.
  DolphinAnalytics::Instance().ReportDolphinStart("ios");

  return YES;
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
  DOLHostQueueRunSync(^{
    auto& system = Core::System::GetInstance();
    
    if (Core::IsRunning(system) && ![EmulationCoordinator shared].userRequestedPause) {
      Core::SetState(system, Core::State::Running);
    }
  });
}

- (void)applicationWillResignActive:(UIApplication*)application {
  // Use async to avoid deadlock: the host queue may be in BindBackbuffer waiting for the main
  // thread (nextDrawable on iOS). If we block main here waiting for the host queue, we deadlock.
  DOLHostQueueRunAsync(^{
    auto& system = Core::System::GetInstance();
    
    if (Core::IsRunning(system) && ![EmulationCoordinator shared].userRequestedPause) {
      Core::SetState(system, Core::State::Paused);
    }
    
    // Write out the configuration in case we don't get a chance later
    Config::Save();
  });
}

- (void)applicationWillTerminate:(UIApplication*)application {
  DOLHostQueueRunSync(^{
    auto& system = Core::System::GetInstance();
    
    if (Core::IsRunning(system)) {
      Core::Stop(Core::System::GetInstance());
      
      // Spin while Core stops
      while (Core::GetState(Core::System::GetInstance()) != Core::State::Uninitialized) {}
    }
    
    Config::Save();
    
    Core::Shutdown(system);
    
    UICommon::ShutdownControllers();
    UICommon::Shutdown();
  });
}

@end
