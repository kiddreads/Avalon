// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <memory>

namespace UICommon {
class GameFile;
}
#endif

NS_ASSUME_NONNULL_BEGIN

@interface GameFilePtrWrapper : NSObject

#ifdef __cplusplus
@property (nonatomic, assign) std::shared_ptr<const UICommon::GameFile> gameFile;
#else
@property (nonatomic, assign) void* gameFile;
#endif

/// Creates a wrapper for a game file at the given path (e.g. from document picker). Returns nil if invalid.
+ (nullable instancetype)wrapperWithPath:(NSString*)path;

/// Display name for the game (SwiftUI-friendly).
- (NSString*)displayName;
/// Cover image or placeholder (SwiftUI-friendly).
- (UIImage*)coverImage;
/// File path for boot parameter.
- (NSString*)filePath;
/// Game ID (e.g. "GALE01") for multi-disc matching.
- (NSString*)gameID;
/// Disc number (0-based) for multi-disc matching.
- (NSInteger)discNumber;
/// Whether the file is NKit-compressed.
- (BOOL)isNKit;
/// Deletes the game file from disk. Returns YES on success.
- (BOOL)deleteFile;

@end

NS_ASSUME_NONNULL_END
