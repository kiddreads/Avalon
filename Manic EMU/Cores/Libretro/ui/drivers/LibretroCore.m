//
//  LibretroCore.m
//  LibretroCore
//
//  Created by Daiuno on 2025/4/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

#import "LibretroCore.h"
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include <boolean.h>

#include <file/file_path.h>
#include <queues/task_queue.h>
#include <string/stdstring.h>
#include <retro_timers.h>

#include "cocoa/cocoa_common.h"
#include "cocoa/apple_platform.h"
#include "../ui_companion_driver.h"
#include "../../audio/audio_driver.h"
#include "../../configuration.h"
#include "../../frontend/frontend.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../input/drivers_keyboard/keyboard_event_apple.h"
#include "../../retroarch.h"
#include "../../tasks/task_content.h"
#include "../../verbosity.h"

#ifdef HAVE_MENU
#include "../../menu/menu_setting.h"
#endif

#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import <MetricKit/MetricKit.h>
#import <MetricKit/MXMetricManager.h>

#ifdef HAVE_MFI
#import <GameController/GCMouse.h>
#endif

#ifdef HAVE_SDL2
#define SDL_MAIN_HANDLED
#include "SDL.h"
#endif

#import "JITSupport.h"

@interface LibretroCore()

@property (assign) BOOL isRunning;

@end

@implementation LibretroCore

+ (instancetype)sharedInstance {
    static LibretroCore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.retroArch_iOS = [RetroArch_iOS new];
    });
    return instance;
}

// 可选：重写 allocWithZone，防止外部 alloc init 创建新实例
+ (id)allocWithZone:(struct _NSZone *)zone {
    static LibretroCore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return self;
}

- (UIViewController *)start {
    self.isRunning = YES;
    [[self getRetroArch] start];
    return [CocoaView get];
}

- (void)pause {
    [[self getRetroArch] pause];
}

- (void)resume {
    [[self getRetroArch] resume];
}

- (void)stop {
    [[self getRetroArch] stop];
}

- (void)mute:(BOOL)mute {
    [[self getRetroArch] mute:mute];
}

- (void)snapshot:(void(^ _Nullable)(UIImage *_Nullable image))completion {
    return [[self getRetroArch] snapshot:completion];
}

- (BOOL)saveState:(void(^ _Nullable)(NSString *_Nullable path))completion {
    return [[self getRetroArch] saveState:completion];
}

- (BOOL)loadState:(NSString *_Nonnull)path {
    return [[self getRetroArch] loadState:path];
}

- (void)fastForward:(float)rate {
    [[self getRetroArch] fastForward:rate];
}

- (void)reload {
    [[self getRetroArch] reload];
}

- (BOOL)loadGame:(NSString *_Nonnull)gamePath corePath:(NSString *_Nonnull)corePath completion:(void(^ _Nullable)(NSDictionary *_Nullable))completion {
    return [[self getRetroArch] loadGame:gamePath corePath:corePath completion:completion];
}

- (void)pressButton:(LibretroButton)button playerIndex:(unsigned)playerIndex {
    [[self getRetroArch] pressButton:(unsigned)button playerIndex:playerIndex];
}

- (void)releaseButton:(LibretroButton)button playerIndex:(unsigned)playerIndex {
    [[self getRetroArch] releaseButton:(unsigned)button playerIndex:playerIndex];
}

- (void)moveStick:(BOOL)isLeft x:(CGFloat)x y:(CGFloat)y playerIndex:(unsigned)playerIndex {
    [[self getRetroArch] moveStick:isLeft x:x y:y playerIndex:playerIndex];
}

- (void)updatePSPCheat:(NSString *_Nonnull)cheatCode cheatFilePath:(NSString *_Nonnull)cheatFilePath reloadGame:(BOOL)reloadGame {
    [[self getRetroArch] updatePSPCheat:cheatCode cheatFilePath:cheatFilePath reloadGame:reloadGame];
}

- (void)setPSPResolution:(unsigned)resolution reload:(BOOL)reload {
    [[self getRetroArch] setPSPResolution:resolution reload:reload];
}

- (void)setPSPLanguage:(unsigned)language {
    [[self getRetroArch] setPSPLanguage:language];
}

- (void)updateCoreConfig:(NSString *_Nonnull)coreName key:(NSString *_Nonnull)key value:(NSString *_Nonnull)value reload:(BOOL)reload {
    [[self getRetroArch] updateCoreConfig:coreName key:key value:value reload:reload];
}

- (void)updateLibretroConfig:(NSString *_Nonnull)key value:(NSString *_Nonnull)value {
    [[self getRetroArch] updateLibretroConfig:key value:value];
}

- (void)setShader:(NSString *_Nullable)path {
    [[self getRetroArch] setShader:path];
}

- (void)addCheatCode:(NSString *_Nonnull)code index:(unsigned)index enable:(BOOL)enable {
    [[self getRetroArch] addCheatCode:code index:index enable:enable];
}

- (void)resetCheatCode {
    [[self getRetroArch] resetCheatCode];
}

- (RetroArch_iOS *)getRetroArch {
#if !TARGET_IPHONE_SIMULATOR
    return (RetroArch_iOS *)self.retroArch_iOS;
#else
    return nil;
#endif
}

- (void)sendEvent:(UIEvent * _Nonnull)event {
    if (self.isRunning) {
        [[self getRetroArch] sendEvent:event];
    }
}

- (void)setWorkspace:(NSString *)workspace {
    [self getRetroArch].workspace = workspace;
}

- (NSString *)workspace {
    return [self getRetroArch].workspace;
}

+ (BOOL)JITAvailable {
    return jit_available();
}

- (NSString * _Nullable)libretroConfigValue:(NSString * _Nonnull)key {
    return [[self getRetroArch] libretroConfigValue:key];
}

- (NSString * _Nullable)coreConfigValue:(NSString * _Nonnull)coreName key:(NSString * _Nonnull)key {
    return [[self getRetroArch] coreConfigValue:coreName key:key];
}

- (void)setRespectSilentMode:(BOOL)respect {
    [[self getRetroArch] setRespectSilentMode:respect];
}

- (void)setDiskIndex:(unsigned)index {
    [[self getRetroArch] setDiskIndex:index];
}

- (NSUInteger)getCurrentDiskIndex {
    return [[self getRetroArch] getCurrentDiskIndex];
}

- (NSUInteger)getDiskCount {
    return [[self getRetroArch] getDiskCount];
}

@end
