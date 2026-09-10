// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

#import "EmulationBootType.h"

#ifdef __cplusplus
#import <memory>
#import "DiscIO/Enums.h"
class BootParameters;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface EmulationBootParameter : NSObject

@property (nonatomic) EmulationBootType bootType;
@property (nonatomic) NSString* path;
@property (nonatomic) NSString* secondPath;
@property (nonatomic) bool isNKit;
/// If set, boot will load this savestate path after starting the game (e.g. from game detail save state slot).
@property (nonatomic, copy, nullable) NSString* savestatePath;

#ifdef __cplusplus
@property (nonatomic) DiscIO::Region iplRegion;
- (std::unique_ptr<BootParameters>) generateDolphinBootParameter;
#else
@property (nonatomic) int iplRegion;
#endif

@end

NS_ASSUME_NONNULL_END
