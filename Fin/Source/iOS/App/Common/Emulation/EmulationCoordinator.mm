// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "EmulationCoordinator.h"

#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "Common/MemoryUtil.h"
#import "Common/WindowSystemInfo.h"

#import "Core/Boot/Boot.h"
#import "Core/BootManager.h"
#import "Core/Config/GraphicsSettings.h"
#import "Core/Config/MainSettings.h"
#import "Core/Config/iOSSettings.h"
#import "Core/Config/WiimoteSettings.h"
#import "Core/Core.h"
#import "Core/Host.h"
#import "Core/HW/GCPad.h"
#import "Core/HW/SI/SI_Device.h"
#import "Core/HW/Wiimote.h"
#import "Core/HW/WiimoteEmu/WiimoteEmu.h"
#import "Core/PowerPC/PowerPC.h"
#import "Core/System.h"
#import "StateRewindAPI.h"

#import "FastmemManager.h"
#import "InputCommon/InputConfig.h"

#import "VideoCommon/Present.h"
#import "VideoCommon/VideoConfig.h"

#import "AudioSessionManager.h"
#import "EmulationBootParameter.h"
#import "HostNotifications.h"
#import "HostQueue.h"

#include <cmath>
#include <cstddef>
#include <memory>

NSString* const DOLEmulationDidStartNotification = @"DOLEmulationDidStartNotification";
NSString* const DOLEmulationDidEndNotification = @"DOLEmulationDidEndNotification";

@implementation EmulationCoordinator
{
  MTKView* _mtkView;
  CAMetalLayer* _metalLayer;
  UIView* _mainDisplayView;
  id<MTLCommandQueue> _clearLayerCommandQueue;  // Reused to avoid per-frame queue creation
  int _targetFrameRate;
  CGSize _lastSurfaceSize;
  bool _hasSurfaceSize;
  std::unique_ptr<u8[]> _rewindCopyBuffer;
  size_t _rewindCopyBufferSize;
}

@synthesize userRequestedPause = _userRequestedPause;

+ (EmulationCoordinator*)shared
{
  static EmulationCoordinator* sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });

  return sharedInstance;
}

- (id)init
{
  if (self = [super init])
  {
    _mtkView = [[MTKView alloc] init];
    // Don't set autoresizingMask - we'll use Auto Layout constraints in requestDisplayOnSuperview
    _targetFrameRate = 120;
    [self applyPreferredFrameRateToView:_mtkView];
    _metalLayer = (CAMetalLayer*)_mtkView.layer;
    _lastSurfaceSize = CGSizeZero;
    _hasSurfaceSize = false;

    self.isExternalDisplayConnected = false;

    // Observe app lifecycle to pause/resume Metal rendering
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidReceiveMemoryWarning)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
  }

  return self;
}

- (void)appDidEnterBackground
{
  // Pause the MTKView so Metal stops requesting drawables in the background.
  // iOS will terminate apps that use GPU resources while backgrounded.
  [_mtkView setPaused:YES];
  _mtkView.enableSetNeedsDisplay = NO;

  // Release reusable Metal resources to reduce memory pressure
  [self invalidateMetalResources];
}

- (void)appWillEnterForeground
{
  // Resume Metal rendering
  _mtkView.enableSetNeedsDisplay = NO;
  [_mtkView setPaused:NO];
  [self applyPreferredFrameRateToView:_mtkView];

  // Force a surface resize so the drawable is recreated at the correct size
  _hasSurfaceSize = false;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self->_mtkView.superview)
    {
      [self->_mtkView.superview setNeedsLayout];
      [self->_mtkView.superview layoutIfNeeded];
      [self notifySurfaceResize];
    }
  });
}

- (void)appDidReceiveMemoryWarning
{
  // Release any cached Metal resources on memory pressure
  [self invalidateMetalResources];
}

- (void)applyPreferredFrameRateToView:(MTKView*)view
{
  view.preferredFramesPerSecond = _targetFrameRate;
  if (@available(iOS 15.0, *))
  {
    SEL setter = @selector(setPreferredFrameRateRange:);
    if ([view respondsToSelector:setter])
    {
      CAFrameRateRange range = CAFrameRateRangeMake(120, 120, 120);
      NSMethodSignature* sig = [view methodSignatureForSelector:setter];
      if (sig && [sig numberOfArguments] >= 3)
      {
        NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:view];
        [inv setSelector:setter];
        [inv setArgument:&range atIndex:2];
        [inv invoke];
      }
    }
  }
}

- (void)setIsExternalDisplayConnected:(bool)connected
{
  self->_isExternalDisplayConnected = connected;

  if (!_isExternalDisplayConnected)
  {
    [self requestDisplayOnSuperview:_mainDisplayView];
  }
}

- (void)registerMainDisplayView:(UIView*)mainView
{
  [self applyPreferredFrameRateToView:_mtkView];
  _mainDisplayView = mainView;

  if (!self.isExternalDisplayConnected)
  {
    [self requestDisplayOnSuperview:mainView];
  }
}

- (void)registerExternalDisplayView:(UIView*)externalView
{
  [self applyPreferredFrameRateToView:_mtkView];
  [self requestDisplayOnSuperview:externalView];
}

- (void)requestDisplayOnSuperview:(UIView*)superview
{
  if (!superview)
  {
    return;
  }

  _mainDisplayView = superview;
  [_mtkView removeFromSuperview];

  // Defer adding the Metal view until the game is running so the drawable is
  // created and sized using the game's resolution (see attachMetalViewForGame).
  if (!Core::IsRunning(Core::System::GetInstance()))
  {
    return;
  }

  [self attachMetalViewToSuperview:superview];
}

- (void)attachMetalViewToSuperview:(UIView*)superview
{
  if (!superview || _mtkView.superview == superview)
  {
    return;
  }

  [_mtkView removeFromSuperview];
  _mtkView.translatesAutoresizingMaskIntoConstraints = NO;
  [superview addSubview:_mtkView];

  [NSLayoutConstraint activateConstraints:@[
    [_mtkView.topAnchor constraintEqualToAnchor:superview.topAnchor],
    [_mtkView.bottomAnchor constraintEqualToAnchor:superview.bottomAnchor],
    [_mtkView.leadingAnchor constraintEqualToAnchor:superview.leadingAnchor],
    [_mtkView.trailingAnchor constraintEqualToAnchor:superview.trailingAnchor]
  ]];

  [self applyPreferredFrameRateToView:_mtkView];

  // Only force layout and resize when superview has valid bounds to avoid "Contradictory frame
  // constraints" / "Invalid frame dimension" from zero or non-finite sizes.
  CGRect superBounds = superview.bounds;
  CGFloat w = superBounds.size.width;
  CGFloat h = superBounds.size.height;
  if (w > 0 && h > 0 && std::isfinite(static_cast<double>(w)) &&
      std::isfinite(static_cast<double>(h)))
  {
    [superview layoutIfNeeded];
    [self resizeSurfaceIfNeeded];
  }

  // Re-apply frame rate and force a layout pass after the view is on screen so the system
  // commits the layer at full refresh rate (same as after screenshot / return from background).
  __weak EmulationCoordinator* weakSelf = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    EmulationCoordinator* strong = weakSelf;
    if (!strong || !strong->_mtkView.superview)
      return;
    [strong applyPreferredFrameRateToView:strong->_mtkView];
    UIView* sv = strong->_mtkView.superview;
    if (sv)
    {
      [sv setNeedsLayout];
      [sv layoutIfNeeded];
      [strong notifySurfaceResize];
    }
  });
}

- (void)runEmulationWithBootParameter:(EmulationBootParameter*)bootParameter
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self emulationLoopWithBootParameter:bootParameter];
  });
}

- (void)emulationLoopWithBootParameter:(EmulationBootParameter*)bootParameter
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    Core::UndeclareAsHostThread();
  });

  DOLHostQueueRunSync(^{
    // One-time migration: default to recommended iOS audio settings (150 ms buffer, fill gaps on)
    // Also migrate away from Cubeb backend which is not available on iOS
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      if (Config::Get(Config::MAIN_AUDIO_BUFFER_SIZE) == 80)
        Config::SetBase(Config::MAIN_AUDIO_BUFFER_SIZE, 150);
      if (!Config::Get(Config::MAIN_AUDIO_FILL_GAPS))
        Config::SetBase(Config::MAIN_AUDIO_FILL_GAPS, true);
      const std::string backend = Config::Get(Config::MAIN_AUDIO_BACKEND);
      if (backend == "Cubeb")
        Config::SetBase(Config::MAIN_AUDIO_BACKEND, std::string(BACKEND_COREAUDIO));
    });

    __block WindowSystemInfo wsi;
    wsi.type = WindowSystemType::iOS;
    wsi.render_surface = (__bridge void*)self->_metalLayer;

    // UIScreen and CALayer properties must be read/written on the main thread.
    __block CGFloat screenScale = 1.0;
    __block bool supports_edr = false;
    dispatch_sync(dispatch_get_main_queue(), ^{
      screenScale = UIScreen.mainScreen.scale;
      if (@available(iOS 17.0, *))
      {
        UIScreen* screen = [UIScreen mainScreen];
        supports_edr = (screen.potentialEDRHeadroom > 1.0f);
      }
      if (@available(iOS 16.0, *))
      {
        self->_metalLayer.wantsExtendedDynamicRangeContent = supports_edr;
      }
    });
    wsi.render_surface_scale = screenScale;
    wsi.display_supports_edr = supports_edr;
    auto& system = Core::System::GetInstance();

    // JIT is not used (App Store policy). Always use interpreter or cached interpreter.
    const PowerPC::CPUCore core = Config::Get(Config::MAIN_CPU_CORE);
    if (core != PowerPC::CPUCore::Interpreter && core != PowerPC::CPUCore::CachedInterpreter)
      Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::CachedInterpreter);
    Config::SetBase(Config::GFX_VERTEX_LOADER_TYPE, VertexLoaderType::Software);
    // Larger code region = fewer slow compiles when using Cached Interpreter
    const int current_mb = Config::Get(Config::MAIN_CACHED_INTERPRETER_CODE_REGION_SIZE_MB);
    if (current_mb < 256)
      Config::SetBase(Config::MAIN_CACHED_INTERPRETER_CODE_REGION_SIZE_MB, 256);

    // Pre-configure Bell Audio flags before boot so InitSoundStream doesn't need
    // to call Config::SetBase during BootCore (which can deadlock).
    const std::string audio_backend = Config::Get(Config::MAIN_AUDIO_BACKEND);
    if (audio_backend == "Bell")
    {
      Config::SetBase(Config::MAIN_BELL_AUDIO_ENABLED, true);
      Config::SetBase(Config::MAIN_BELL_AUDIO_ADAPTIVE_BUFFERING, true);
      Config::SetBase(Config::MAIN_BELL_AUDIO_NEON_MIXING, true);
      Config::SetBase(Config::MAIN_BELL_AUDIO_DRIVEN_PACING, true);
      Config::SetBase(Config::MAIN_BELL_AUDIO_UNDERRUN_PROTECTION, true);
      Config::SetBase(Config::MAIN_BELL_AUDIO_DYNAMIC_RATE_CORRECTION, true);
      Config::SetBase(Config::MAIN_BELL_AUDIO_HQ_PROCESSING, true);
    }

    [[AudioSessionManager shared] prepareForEmulationPlayback];

    std::unique_ptr<BootParameters> boot = [bootParameter generateDolphinBootParameter];

    if (!BootManager::BootCore(system, std::move(boot), wsi))
    {
      PanicAlertFmt("Failed to init core!");
    }
  });

  while (Core::GetState(Core::System::GetInstance()) == Core::State::Starting)
  {
    [NSThread sleepForTimeInterval:0.1];
  }

  [[NSNotificationCenter defaultCenter] postNotificationName:DOLEmulationDidStartNotification
                                                      object:self
                                                    userInfo:nil];

  // Attach Metal view/drawable now that the game is running; backend will size from game resolution.
  dispatch_sync(dispatch_get_main_queue(), ^{
    if (self->_mainDisplayView)
      [self attachMetalViewToSuperview:self->_mainDisplayView];
  });

  while (Core::IsRunning(Core::System::GetInstance()))
  {
    [NSThread sleepForTimeInterval:0.1];
  }

  [[AudioSessionManager shared] endEmulationPlayback];

  dispatch_sync(dispatch_get_main_queue(), ^{
    Core::DeclareAsHostThread();
  });

  [[NSNotificationCenter defaultCenter] postNotificationName:DOLEmulationDidEndNotification
                                                      object:self
                                                    userInfo:nil];

  _mainDisplayView = nil;
}

- (bool)userRequestedPause
{
  return _userRequestedPause;
}

- (void)setUserRequestedPause:(bool)userRequestedPause
{
  if (userRequestedPause == _userRequestedPause)
  {
    return;
  }

  _userRequestedPause = userRequestedPause;
  // Use async so the main thread (e.g. menu tap) never blocks waiting for the host queue (avoids freeze).
  DOLHostQueueRunAsync(^{
    Core::SetState(Core::System::GetInstance(),
                   self->_userRequestedPause ? Core::State::Paused : Core::State::Running);
  });
}

- (void)updateTargetFrameRate
{
  [self setTargetFrameRate:_targetFrameRate];
}

- (void)clearMetalLayer
{
  // Defer so we don't take a drawable the backend just presented (avoids "texture should not be called after already presenting").
  __weak EmulationCoordinator* weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf clearMetalLayerNow];
  });
}

- (void)clearMetalLayerNow
{
  id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];

  if (drawable == nil)
  {
    return;
  }

  id<MTLDevice> device = _mtkView.preferredDevice;
  if (device == nil)
  {
    return;
  }

  // Reuse a single command queue instead of creating one every time (reduces allocation/sync overhead)
  if (_clearLayerCommandQueue == nil)
  {
    _clearLayerCommandQueue = [device newCommandQueue];
  }
  id<MTLCommandQueue> commandQueue = _clearLayerCommandQueue;

  MTLRenderPassDescriptor* renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
  renderPass.colorAttachments[0].texture = drawable.texture;
  renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
  renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
  renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

  id<MTLRenderCommandEncoder> commandEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
  commandEncoder.label = @"Clear";
  [commandEncoder endEncoding];

  [commandBuffer presentDrawable:drawable];
  [commandBuffer commit];
}

- (void)invalidateMetalResources
{
  _clearLayerCommandQueue = nil;
}

- (void)setTargetFrameRate:(int)frameRate
{
  if (frameRate == _targetFrameRate)
    return;
  _targetFrameRate = frameRate;
  [self applyPreferredFrameRateToView:_mtkView];
}

- (int)targetFrameRate
{
  return _targetFrameRate;
}

// MARK: - SwiftUI Support

- (void)requestStop
{
  Host_Message(HostMessageID::WMUserStop);
}

- (void)loadState:(int)slot
{
  DOLHostQueueRunAsync(^{
    State::Load(Core::System::GetInstance(), slot);
  });
}

- (void)saveState:(int)slot
{
  DOLHostQueueRunAsync(^{
    State::Save(Core::System::GetInstance(), slot);
  });
}

- (void)copyStateFromSlot:(int)fromSlot toSlot:(int)toSlot
{
  DOLHostQueueRunSync(^{
    Core::System& system = Core::System::GetInstance();
    const size_t requiredSize = State::GetSaveStateSize(system);
    if (_rewindCopyBufferSize < requiredSize)
    {
      _rewindCopyBuffer.reset(new u8[requiredSize]);
      _rewindCopyBufferSize = requiredSize;
    }
    State::SaveToBuffer(system, _rewindCopyBuffer.get(), _rewindCopyBufferSize);
    State::Load(system, fromSlot);
    State::Save(system, toSlot);
    State::LoadFromBuffer(system, _rewindCopyBuffer.get(), requiredSize);
  });
}

- (void)notifySurfaceResize
{
  UIView* superview = _mtkView.superview;
  if (superview)
  {
    CGRect superBounds = superview.bounds;
    CGFloat w = superBounds.size.width;
    CGFloat h = superBounds.size.height;
    if (w > 0 && h > 0 && std::isfinite(static_cast<double>(w)) &&
        std::isfinite(static_cast<double>(h)))
      [superview layoutIfNeeded];
  }
  [self resizeSurfaceIfNeeded];
}

- (void)notifySurfaceResizeForced
{
  _hasSurfaceSize = false;
  [self notifySurfaceResize];
}

- (void)resizeSurfaceIfNeeded
{
  UIView* superview = _mtkView.superview;
  if (!superview)
    return;

  CGRect superBounds = superview.bounds;
  CGFloat w = superBounds.size.width;
  CGFloat h = superBounds.size.height;
  if (w <= 0 || h <= 0 || !std::isfinite(static_cast<double>(w)) ||
      !std::isfinite(static_cast<double>(h)))
    return;

  // Ensure constraints have been applied before reading bounds.
  [superview layoutIfNeeded];

  const CGSize size = _mtkView.bounds.size;
  if (size.width <= 0.0 || size.height <= 0.0)
    return;

  if (_hasSurfaceSize && CGSizeEqualToSize(size, _lastSurfaceSize))
    return;

  _lastSurfaceSize = size;
  _hasSurfaceSize = true;

  if (g_presenter)
    g_presenter->ResizeSurface();
}

- (bool)isWiiGame
{
  return Core::System::GetInstance().IsWii();
}

- (bool)isWiimoteTouchPadAttached
{
  if (Config::Get(Config::GetInfoForWiimoteSource(0)) != WiimoteSource::Emulated)
  {
    return false;
  }
  
  const auto wiimote = static_cast<WiimoteEmu::Wiimote*>(Wiimote::GetConfig()->GetController(0));
  if (!wiimote)
  {
    return false;
  }
  
  const std::string deviceString = wiimote->GetDefaultDevice().ToString();
  // Treat as attached if the device string contains "Touch" or "iOS"
  return deviceString.find("Touch") != std::string::npos || deviceString.find("iOS") != std::string::npos;
}

- (bool)isGameCubeTouchPadAttached
{
  if (Config::Get(Config::GetInfoForSIDevice(0)) == SerialInterface::SIDEVICE_NONE)
  {
    return false;
  }
  
  const auto gcDevice = Pad::GetConfig()->GetController(0);
  if (!gcDevice)
  {
    return false;
  }

  const std::string deviceString = gcDevice->GetDefaultDevice().ToString();
  // Treat as attached if the device string contains "Touch" or "iOS"
  return deviceString.find("Touch") != std::string::npos || deviceString.find("iOS") != std::string::npos;
}

- (int)activeWiimoteExtension
{
  if (![self isWiimoteTouchPadAttached])
  {
    return -1;
  }
  
  const auto wiimote = static_cast<WiimoteEmu::Wiimote*>(Wiimote::GetConfig()->GetController(0));
  return static_cast<int>(wiimote->GetActiveExtensionNumber());
}

- (bool)isWiimoteSideways
{
  if (![self isWiimoteTouchPadAttached])
  {
    return false;
  }
  
  const auto wiimote = static_cast<WiimoteEmu::Wiimote*>(Wiimote::GetConfig()->GetController(0));
  return wiimote->IsSideways();
}

- (void)runEmulationWithBootParameterObject:(id)bootParameter
{
  // Cast to the actual type and call the real method
  [self runEmulationWithBootParameter:(EmulationBootParameter*)bootParameter];
}

@end

