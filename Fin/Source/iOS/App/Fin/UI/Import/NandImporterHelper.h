// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NandImporterHelper : NSObject

/// Runs NAND import on a background thread. Calls completion on main queue when done.
+ (void)importNandAtPath:(NSString*)path completion:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
