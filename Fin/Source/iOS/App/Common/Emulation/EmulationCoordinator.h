// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

@class EmulationBootParameter;
@class UIView;

extern NSString* const DOLEmulationDidStartNotification;
extern NSString* const DOLEmulationDidEndNotification;

NS_ASSUME_NONNULL_BEGIN

@interface EmulationCoordinator : NSObject

+ (EmulationCoordinator*)shared;

@property (nonatomic, setter=setIsExternalDisplayConnected:) bool isExternalDisplayConnected;
@property (nonatomic) bool userRequestedPause;
@property (nonatomic, assign) int targetFrameRate;
@property (nonatomic, readonly) bool isWiiGame;
@property (nonatomic, readonly) bool isWiimoteTouchPadAttached;
@property (nonatomic, readonly) bool isGameCubeTouchPadAttached;
@property (nonatomic, readonly) int activeWiimoteExtension;
@property (nonatomic, readonly) bool isWiimoteSideways;

- (void)registerMainDisplayView:(UIView*)mainView NS_SWIFT_NAME(registerMainDisplay(_:));
- (void)registerExternalDisplayView:(UIView*)externalView;
- (void)runEmulationWithBootParameter:(EmulationBootParameter*)bootParameter;
- (void)updateTargetFrameRate;
- (void)clearMetalLayer;
- (void)invalidateMetalResources;

// SwiftUI support
- (void)requestStop;
- (void)loadState:(int)slot;
- (void)saveState:(int)slot;
/// Copy state from one slot to another (for rewind current/last). Runs on host queue; use to copy 10→11 before saving new state to 10.
- (void)copyStateFromSlot:(int)fromSlot toSlot:(int)toSlot;
/// Notify that the surface may need resize (e.g. rotation or view bounds changed).
- (void)notifySurfaceResize;
/// Force backend resize even if view size unchanged (e.g. resolution/MSAA/MetalFX changed).
- (void)notifySurfaceResizeForced;

/// Alternative method for Swift - accepts id since EmulationBootParameter contains C++
- (void)runEmulationWithBootParameterObject:(id)bootParameter;

@end

NS_ASSUME_NONNULL_END

