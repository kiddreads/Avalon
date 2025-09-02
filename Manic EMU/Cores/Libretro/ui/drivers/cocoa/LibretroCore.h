//
//  LibretroCore.h
//  LibretroCore
//
//  Created by Daiuno on 2025/4/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CheevosBridge.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LibretroButton) {
   LibretroButtonUp = 4,
   LibretroButtonDown = 5,
   LibretroButtonLeft = 6,
   LibretroButtonRight = 7,
   LibretroButtonA = 8,
   LibretroButtonB = 0,
   LibretroButtonX = 9,
   LibretroButtonY = 1,
   LibretroButtonSelect = 2,
   LibretroButtonStart = 3,
   LibretroButtonL1 = 10,
   LibretroButtonR1 = 11,
   LibretroButtonL2 = 12,
   LibretroButtonR2 = 13,
   LibretroButtonL3 = 14,
   LibretroButtonR3 = 15,
};

extern NSString * const RetroAchievementsNotification;

@interface LibretroCore : NSObject

@property(nonatomic, strong) id retroArch_iOS;
@property (nonatomic, copy, nullable) NSString *workspace;

+ (instancetype)sharedInstance;

- (UIViewController *)startWithCustomSaveDir:(NSString *_Nullable)customSaveDir;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)mute:(BOOL)mute;
- (void)snapshot:(void(^ _Nullable)(UIImage *_Nullable image))completion;
- (BOOL)saveState:(void(^ _Nullable)(NSString *_Nullable path))completion;
- (BOOL)loadState:(NSString *_Nonnull)path;
- (void)fastForward:(float)rate;
- (void)reload;
- (BOOL)loadGame:(NSString *_Nonnull)gamePath corePath:(NSString *_Nonnull)corePath completion:(void(^ _Nullable)(NSDictionary *_Nullable))completion;
- (void)sendEvent:(UIEvent * _Nonnull)event;
- (void)pressButton:(LibretroButton)button playerIndex:(unsigned)playerIndex;
- (void)releaseButton:(LibretroButton)button playerIndex:(unsigned)playerIndex;
///x,y取值范围 -1~1
- (void)moveStick:(BOOL)isLeft x:(CGFloat)x y:(CGFloat)y playerIndex:(unsigned)playerIndex;
- (void)updatePSPCheat:(NSString *_Nonnull)cheatCode cheatFilePath:(NSString *_Nonnull)cheatFilePath reloadGame:(BOOL)reloadGame;
- (void)setPSPResolution:(unsigned)resolution reload:(BOOL)reload;
- (void)setPSPLanguage:(unsigned)language;
- (void)updateCoreConfig:(NSString *_Nonnull)coreName key:(NSString *_Nonnull)key value:(NSString *_Nonnull)value reload:(BOOL)reload;
- (void)updateCoreConfig:(NSString *_Nonnull)coreName configs:(NSDictionary<NSString*, NSString*> *_Nullable)configs reload:(BOOL)reload;
- (void)updateLibretroConfig:(NSString *_Nonnull)key value:(NSString *_Nonnull)value;
- (void)updateLibretroConfigs:(NSDictionary<NSString*, NSString*> *_Nullable)configs;
- (void)setShader:(NSString *_Nullable)path;
- (void)addCheatCode:(NSString *_Nonnull)code index:(unsigned)index enable:(BOOL)enable;
- (void)resetCheatCode;
+ (BOOL)JITAvailable;
- (NSString * _Nullable)coreConfigValue:(NSString * _Nonnull)coreName key:(NSString * _Nonnull)key;
- (NSString * _Nullable)libretroConfigValue:(NSString * _Nonnull)key;
- (void)setRespectSilentMode:(BOOL)respect;
- (void)setDiskIndex:(unsigned)index delay:(BOOL)delay;
- (NSUInteger)getCurrentDiskIndex;
- (NSUInteger)getDiskCount;
- (void)setPSXAnalog:(BOOL)isAnalog;
- (void)setReloadDelay:(double)delay;
- (void)turnOffHardcode;
- (void)resetRetroAchievements;
- (void)setCustomSaveExtension:(NSString *_Nullable)customSaveExtension;
- (void)setEnableRumble:(BOOL)enable;
- (BOOL)getSensorEnable:(int)playerIndex;

@end

NS_ASSUME_NONNULL_END
