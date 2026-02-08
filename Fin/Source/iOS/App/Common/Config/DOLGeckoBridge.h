// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Represents a Gecko code for display in SwiftUI
@interface DOLGeckoCode : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *creator;
@property (nonatomic, copy, nullable) NSString *notes;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL userDefined;
@property (nonatomic, assign) NSInteger codeIndex;

@end

/// Bridge for accessing Gecko codes from Swift
@interface DOLGeckoBridge : NSObject

/// Load codes for the current game (uses current game ID from DOLConfigBridge)
+ (void)loadCodesForCurrentGame;

/// Load codes for a specific game
+ (void)loadCodesForGameId:(NSString *)gameId gametdbId:(NSString *)gametdbId revision:(int)revision;

/// Get all loaded codes
+ (NSArray<DOLGeckoCode *> *)codes;

/// Get the count of loaded codes
+ (NSInteger)codeCount;

/// Set enabled state for a code at index
+ (void)setEnabled:(BOOL)enabled forCodeAtIndex:(NSInteger)index;

/// Save current codes to file
+ (void)saveCodes;

/// Download codes from the internet. Returns YES on success.
+ (void)downloadCodesWithCompletion:(void (^)(BOOL success, NSInteger downloadedCount, NSInteger addedCount, NSString * _Nullable errorMessage))completion;

/// Add a new code
+ (BOOL)addCodeWithName:(NSString *)name creator:(NSString *)creator notes:(nullable NSString *)notes codeLines:(NSArray<NSString *> *)codeLines;

/// Delete code at index
+ (void)deleteCodeAtIndex:(NSInteger)index;

/// Check if a game is currently loaded
+ (BOOL)isGameLoaded;

/// Get the current game ID
+ (NSString *)currentGameId;

/// Get the current game name (for display)
+ (NSString *)currentGameName;

@end

NS_ASSUME_NONNULL_END
