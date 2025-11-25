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
#include <stdarg.h>

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
#include "../../cheevos/cheevos.h"
#include "../../deps/rcheevos/include/rc_client.h"

NSString * const RetroAchievementsNotification = @"RetroAchievementsNotification";
NSString * const LibretroDidShutdownNotification = @"LibretroDidShutdownNotification";
NSString * const DidConnectToWFCNotification = @"DidConnectToWFCNotification";
NSString * const DidDisconnectFromWFCNotification = @"DidDisconnectFromWFCNotification";
NSString * const MAMEGameFileMissingNotification = @"MAMEGameFileMissingNotification";

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

- (UIViewController *)startWithCustomSaveDir:(NSString *_Nullable)customSaveDir {
    self.isRunning = YES;
    [[self getRetroArch] startWithCustomSaveDir:customSaveDir];
    cheevos_event_register_callback(cheevosDidTrigger);
    shutdown_register_callback(shutdownCallback);
    log_register_callback(libretroLogCallback);
    return [CocoaView get];
}

- (void)pause {
    [[self getRetroArch] pause];
}

- (void)resume {
    [[self getRetroArch] resume];
}

- (void)stop {
    self.isRunning = NO;
    cheevos_event_register_callback(NULL);
    shutdown_register_callback(NULL);
    wfc_status_register_callback(NULL);
    log_register_callback(NULL);
    [[self getRetroArch] stop];
}

- (void)mute:(BOOL)mute {
    [[self getRetroArch] mute:mute];
}

- (void)snapshot:(void(^ _Nullable)(UIImage *_Nullable image))completion {
#if !TARGET_IPHONE_SIMULATOR
    [[self getRetroArch] snapshot:completion];
#else
    if (completion) {
        completion(nil);
    }
#endif
    
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

- (void)reloadByKeepState:(BOOL)keepState {
    [[self getRetroArch] reloadByKeepState:keepState];
}

- (BOOL)loadGame:(NSString *_Nonnull)gamePath corePath:(NSString *_Nonnull)corePath completion:(void(^ _Nullable)(NSDictionary *_Nullable))completion {
    return [[self getRetroArch] loadGame:gamePath corePath:corePath completion:completion];
}

- (void)loadCoreWithoutContent:(NSString *_Nonnull)corePath {
    [[self getRetroArch] loadCoreWithoutContent:corePath];
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

- (void)updateCoreConfig:(NSString *_Nonnull)coreName key:(NSString *_Nonnull)key value:(NSString *_Nonnull)value reload:(BOOL)reload {
    [[self getRetroArch] updateCoreConfig:coreName key:key value:value reload:reload];
}

- (void)updateCoreConfig:(NSString *_Nonnull)coreName configs:(NSDictionary<NSString*, NSString*> *_Nullable)configs reload:(BOOL)reload {
    [[self getRetroArch] updateCoreConfig:coreName configs:configs reload:reload];
}

- (void)updateRunningCoreConfigs:(NSDictionary<NSString*, NSString*> *_Nullable)configs flush:(BOOL)flush {
    [[self getRetroArch] updateRunningCoreConfigs:configs flush:flush];
}

- (void)updateLibretroConfig:(NSString *_Nonnull)key value:(NSString *_Nonnull)value {
    [[self getRetroArch] updateLibretroConfig:key value:value];
}

- (void)updateLibretroConfigs:(NSDictionary<NSString*, NSString*> *_Nullable)configs {
    [[self getRetroArch] updateLibretroConfigs:configs];
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

- (void)setDiskIndex:(unsigned)index delay:(BOOL)delay {
    [[self getRetroArch] setDiskIndex:index delay:delay];
}

- (NSUInteger)getCurrentDiskIndex {
    return [[self getRetroArch] getCurrentDiskIndex];
}

- (NSUInteger)getDiskCount {
    return [[self getRetroArch] getDiskCount];
}

- (void)setPSXAnalog:(BOOL)isAnalog {
    [[self getRetroArch] setPSXAnalog:isAnalog];
}

- (void)setReloadDelay:(double)delay {
    [[self getRetroArch] setReloadDelay:delay];
}

+ (CheevosAchievement *)convertAchievement:(rc_client_achievement_t *)a {
    if ([[NSString stringWithUTF8String:a->badge_name] isEqualToString:@"00000"]) {
        return nil;
    }
    CheevosAchievement* obj = [CheevosAchievement new];
    obj.title = a->title ? [NSString stringWithUTF8String:a->title] : nil;
    obj._description = a->description ? [NSString stringWithUTF8String:a->description] : nil;
    obj.badgeName = [NSString stringWithUTF8String:a->badge_name];
    obj.measuredProgress = [NSString stringWithUTF8String:a->measured_progress];
    obj.measuredPercent = (CGFloat)a->measured_percent;
    obj._id = (NSInteger)a->id;
    obj.points = (NSInteger)a->points;
    obj.unlockTime = (a->unlock_time ? [NSDate dateWithTimeIntervalSince1970:a->unlock_time] : nil);
    obj.state = (NSInteger)a->state;
    obj.category = (NSInteger)a->state;
    obj.bucket = (NSInteger)a->bucket;
    obj.unlocked = (a->unlocked != 0);
    obj.rarity = (CGFloat)a->rarity;
    obj.rarityHardcore = (CGFloat)a->rarity_hardcore;
    obj.type = (NSInteger)a->type;
    char url1[256];
    if (rc_client_achievement_get_image_url(a, RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED, url1, sizeof(url1)) == RC_OK) {
        obj.unlockedBadgeUrl = [NSString stringWithCString:url1 encoding:NSUTF8StringEncoding];
    }
    char url2[256];
    if (rc_client_achievement_get_image_url(a, RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED, url2, sizeof(url2)) == RC_OK) {
        obj.activeBadgeUrl = [NSString stringWithCString:url2 encoding:NSUTF8StringEncoding];
    }
    return obj;
}

static void cheevosDidTrigger(uint32_t type, void* object1, void* object2) {
    if (type == RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED) {
        //获得成就
        if (object1) {
            rc_client_achievement_t *a = (rc_client_achievement_t *)object1;
            CheevosAchievement *achievement = [LibretroCore convertAchievement:a];
            if (!achievement) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:achievement];
            });
        }
        
    } else if (type == 8888) {
        //启动游戏
        if (object1 && object2) {
            rc_client_game_t *g = (rc_client_game_t *)object1;
            rc_client_user_game_summary_t *s = (rc_client_user_game_summary_t *)object2;
            
            CheevosSummary* summary = [CheevosSummary new];
            summary.title = g->title ? [NSString stringWithUTF8String:g->title] : nil;
            summary.coreAchievementsNum = (NSInteger)s->num_core_achievements;
            summary.unofficialAchievementsNum = (NSInteger)s->num_unofficial_achievements;
            summary.unlockedAchievementsNum = (NSInteger)s->num_unlocked_achievements;
            summary.unsupportedAchievementsNum = (NSInteger)s->num_unsupported_achievements;
            summary.corePoints = (NSInteger)s->points_core;
            summary.unlockedPoints = (NSInteger)s->points_unlocked;
            char url[256];
            if (rc_client_game_get_image_url(g, url, sizeof(url)) == RC_OK) {
                summary.badgeUrl = [NSString stringWithCString:url encoding:NSUTF8StringEncoding];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:summary];
            });
            
        }
    } else if (type == RC_CLIENT_EVENT_GAME_COMPLETED) {
        //所有成就收集完成
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:[CheevosCompletion new]];
        });
        
    } else if (type == RC_CLIENT_EVENT_SERVER_ERROR) {
        //发生错误
        if (object1) {
            rc_client_server_error_t *error = (rc_client_server_error_t *)object1;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:error->error_message ? [NSString stringWithUTF8String:error->error_message] : @"RetroAchievements Server Error"];
            });
        }
    } else if (type == RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_SHOW) {
        //挑战提示
        if (object1) {
            rc_client_achievement_t *a = (rc_client_achievement_t *)object1;
            CheevosAchievement *achievement = [LibretroCore convertAchievement:a];
            if (!achievement) {
                return;
            }
            achievement.isChallengeAchievement = YES;
            achievement.show = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:achievement];
            });
        }
    } else if (type == RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_HIDE) {
        //挑战隐藏
        if (object1) {
            rc_client_achievement_t *a = (rc_client_achievement_t *)object1;
            CheevosAchievement *achievement = [LibretroCore convertAchievement:a];
            if (!achievement) {
                return;
            }
            achievement.isChallengeAchievement = YES;
            achievement.show = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:achievement];
            });
        }
    } else if (type == RC_CLIENT_EVENT_LEADERBOARD_TRACKER_SHOW) {
        //排行榜追踪展示
        if (object1) {
            rc_client_leaderboard_tracker_t *a = (rc_client_leaderboard_tracker_t *)object1;
            CheevosLeaderboardTracker* obj = [CheevosLeaderboardTracker new];
            obj.show = YES;
            obj._id = a->id;
            obj.display = [NSString stringWithUTF8String:a->display];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:obj];
            });
        }
        
    } else if (type == RC_CLIENT_EVENT_LEADERBOARD_TRACKER_HIDE) {
        //排行榜追踪隐藏
        if (object1) {
            rc_client_leaderboard_tracker_t *a = (rc_client_leaderboard_tracker_t *)object1;
            CheevosLeaderboardTracker* obj = [CheevosLeaderboardTracker new];
            obj.show = NO;
            obj._id = a->id;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:obj];
            });
        }
    } else if (type == RC_CLIENT_EVENT_LEADERBOARD_TRACKER_UPDATE) {
        //排行榜追踪更新
        if (object1) {
            rc_client_leaderboard_tracker_t *a = (rc_client_leaderboard_tracker_t *)object1;
            CheevosLeaderboardTracker* obj = [CheevosLeaderboardTracker new];
            obj.show = YES;
            obj._id = a->id;
            obj.display = [NSString stringWithUTF8String:a->display];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:obj];
            });
        }
    } else if (type == RC_CLIENT_EVENT_LEADERBOARD_STARTED) {
        //排行榜开始
        if (object1) {
            rc_client_leaderboard_t *a = (rc_client_leaderboard_t *)object1;
            CheevosLeaderboard* obj = [CheevosLeaderboard new];
            obj.title = a->title ? [NSString stringWithUTF8String:a->title] : nil;
            obj._description = a->description ? [NSString stringWithUTF8String:a->description] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:obj];
            });
        }
    } else if (type == RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW) {
        //进度展示
        if (object1) {
            rc_client_achievement_t *a = (rc_client_achievement_t *)object1;
            
            CheevosAchievement *achievement = [LibretroCore convertAchievement:a];
            if (!achievement) {
                return;
            }
            
            achievement.isProgressAchievement = YES;
            achievement.show = YES;

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:achievement];
            });
        }
        
    } else if (type == RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_HIDE) {
        //进度隐藏
        CheevosAchievement *achievement = [CheevosAchievement new];
        achievement.isProgressAchievement = YES;
        achievement.show = NO;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:achievement];
        });
        
    } else if (type == RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_UPDATE) {
        //进度更新
        if (object1) {
            rc_client_achievement_t *a = (rc_client_achievement_t *)object1;
            
            CheevosAchievement *achievement = [LibretroCore convertAchievement:a];
            if (!achievement) {
                return;
            }
            
            achievement.isProgressAchievement = YES;
            achievement.show = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RetroAchievementsNotification object:achievement];
            });
        }
    }
}

- (void)turnOffHardcode {
    [[self getRetroArch] turnOffHardcode];
}

- (void)resetRetroAchievements {
    [[self getRetroArch] resetRetroAchievements];
}

- (void)setCustomSaveExtension:(NSString *_Nullable)customSaveExtension {
    [[self getRetroArch] setCustomSaveExtension:customSaveExtension];
}

- (void)setEnableRumble:(BOOL)enable {
    [[self getRetroArch] setEnableRumble:enable];
}

- (BOOL)getSensorEnable:(int)playerIndex {
    return [[self getRetroArch] getSensorEnable:playerIndex];
}

static void shutdownCallback(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:LibretroDidShutdownNotification object:nil];
    });
}

- (void)startWFCStatusMonitor {
    wfc_status_register_callback(wfcStatusCallback);
}

static void wfcStatusCallback(bool isConnect) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isConnect) {
            [[NSNotificationCenter defaultCenter] postNotificationName:DidConnectToWFCNotification object:nil];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:DidDisconnectFromWFCNotification object:nil];
        }
    });
}

static BOOL g_enableMonitorLibretroLog = NO;
- (void)setLibretroLogMonitor:(BOOL)enable {
    g_enableMonitorLibretroLog = enable;
}

static void libretroLogCallback(enum retro_log_level level, const char *fmt, va_list args) {
    if (!g_enableMonitorLibretroLog) {
        return;
    }
    // 使用 va_list 格式化字符串
    char buffer[4096];
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    
    // 根据日志级别输出
    NSString *logMessage = [NSString stringWithUTF8String:buffer];
    
    switch (level) {
        case RETRO_LOG_ERROR:
            if ([logMessage containsString:@"Required files are missing,"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:MAMEGameFileMissingNotification object:nil];
                });
            }
            break;
        default:
            break;
    }
}

- (void)setNDSCustomLayout:(NSString *_Nullable)layout {
    if (layout) {
        if ([layout componentsSeparatedByString:@","].count == 10) {
            set_melonds_custom_layout([layout cStringUsingEncoding:NSUTF8StringEncoding]);
            [self setCoreOptionNeedsUpdate];
        }
    } else {
        set_melonds_custom_layout(NULL);
        [self setCoreOptionNeedsUpdate];
    }
}

- (void)set3DSCustomLayout:(NSString *_Nullable)layout {
    if (layout) {
        if ([layout componentsSeparatedByString:@","].count == 10) {
            set_azahar_custom_layout([layout cStringUsingEncoding:NSUTF8StringEncoding]);
            [self setCoreOptionNeedsUpdate];
        }
    } else {
        set_azahar_custom_layout(NULL);
        [self setCoreOptionNeedsUpdate];
    }
}

- (void)setNDSWFCDNS:(NSString *_Nullable)nds {
    if (nds) {
        set_melonds_wfc_dns([nds cStringUsingEncoding:NSUTF8StringEncoding]);
        [self setCoreOptionNeedsUpdate];
    } else {
        set_melonds_wfc_dns(NULL);
        [self setCoreOptionNeedsUpdate];
    }
}

- (void)setCoreOptionNeedsUpdate {
    // 通知核心配置已更新
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (runloop_st->core_options) {
        runloop_st->core_options->updated = true;
    }
}

- (void)sendTouchEventX:(CGFloat)x y:(CGFloat)y {
    [[self getRetroArch] sendTouchEventX:x y:y];
}

- (void)releaseTouchEvent {
    [[self getRetroArch] releaseTouchEvent];
}

- (NSString *_Nullable)getCoreConfigs:(NSString *_Nonnull)coreName {
    return [[self getRetroArch] getCoreConfigs:coreName];
}

- (void)updateFBNeoCheatCode:(NSArray<NSString *> *_Nonnull)keys enable:(BOOL)enable {
    [[self getRetroArch] updateFBNeoCheatCode:keys enable:enable];
}

- (void)setFastforwardFrameSkip:(BOOL)frameSkip {
    [[self getRetroArch] setFastforwardFrameSkip:frameSkip];
}

@end
