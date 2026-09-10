// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Mapping type for controller configuration
typedef NS_ENUM(NSInteger, DOLMappingType) {
  DOLMappingTypePad = 0,
  DOLMappingTypeWiimote = 1
};

/// Device filter type for device selection
typedef NS_ENUM(NSInteger, DOLDeviceFilterType) {
  DOLDeviceFilterTypeNone = 0,
  DOLDeviceFilterTypeTouchscreenExceptPad = 1,
  DOLDeviceFilterTypeTouchscreenExceptWii = 2,
  DOLDeviceFilterTypeTouchscreenAll = 3,
  /// Exclude all touchscreen devices (physical controllers only)
  DOLDeviceFilterTypePhysicalOnly = 4
};

/// Extension types for Wiimote
typedef NS_ENUM(NSInteger, DOLWiimoteExtension) {
  DOLWiimoteExtensionNone = 0,
  DOLWiimoteExtensionNunchuk = 1,
  DOLWiimoteExtensionClassic = 2,
  DOLWiimoteExtensionGuitar = 3,
  DOLWiimoteExtensionDrums = 4,
  DOLWiimoteExtensionTurntable = 5,
  DOLWiimoteExtensionUDrawTablet = 6,
  DOLWiimoteExtensionDrawsomeTablet = 7,
  DOLWiimoteExtensionTaTaCon = 8
};

/// Setting type for numeric settings
typedef NS_ENUM(NSInteger, DOLSettingType) {
  DOLSettingTypeDouble = 0,
  DOLSettingTypeBool = 1
};

/// Represents a control group in the mapping UI
@interface DOLControlGroup : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uiName;
@property (nonatomic, assign) NSInteger groupIndex;
@property (nonatomic, assign) BOOL isExtensionGroup;
@property (nonatomic, assign) BOOL hasEnabledSetting;
@property (nonatomic, assign) BOOL isEnabled;
@end

/// Represents a single control (button/axis) in a control group
@interface DOLControl : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uiName;
@property (nonatomic, copy) NSString *expression;
@property (nonatomic, assign) NSInteger controlIndex;
@property (nonatomic, assign) BOOL shouldTranslate;
@end

/// Represents a numeric setting in a control group
@interface DOLNumericSetting : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uiName;
@property (nonatomic, copy, nullable) NSString *uiDescription;
@property (nonatomic, copy, nullable) NSString *uiSuffix;
@property (nonatomic, assign) DOLSettingType settingType;
@property (nonatomic, assign) NSInteger settingIndex;
@property (nonatomic, assign) double doubleValue;
@property (nonatomic, assign) double minValue;
@property (nonatomic, assign) double maxValue;
@property (nonatomic, assign) BOOL boolValue;
@end

/// Represents a profile for loading/saving
@interface DOLProfile : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL isStock;
@end

/// Represents a device for selection
@interface DOLDevice : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) BOOL isDisconnected;
@end

/// Represents an input for the input display
@interface DOLInput : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double value;
@end

/// Represents an extension attachment
@interface DOLExtensionAttachment : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) NSInteger index;
@end

/// Objective-C bridge for Dolphin's C++ Input/Controller system.
/// Allows Swift code to interact with controller mapping functionality.
@interface DOLMappingBridge : NSObject

// MARK: - Controller Management

/// Initialize mapping for a specific controller type and port
+ (void)initializeForType:(DOLMappingType)type port:(NSInteger)port;

/// Save the current configuration
+ (void)saveConfig;

/// Refresh connected devices
+ (void)refreshDevices;

// MARK: - Device Management

/// Get the default device string for the current controller
+ (NSString *)defaultDevice;

/// Set the default device for the current controller
+ (void)setDefaultDevice:(NSString *)deviceString;

/// Get all available devices with optional filter
+ (NSArray<DOLDevice *> *)devicesWithFilter:(DOLDeviceFilterType)filterType;

/// Check if a device is a touchscreen device
+ (BOOL)isTouchscreenDevice:(NSString *)deviceString;

/// Check if a device is an MFi physical controller
+ (BOOL)isMFiPhysicalController:(NSString *)deviceString;

/// Touchscreen device string for port 0 (GameCube pad = iOS/0/Touchscreen, Wii = iOS/4/Touchscreen)
+ (NSString *)touchscreenDeviceStringForPort0WithMappingType:(DOLMappingType)type;

/// Load default profile for device type (touchscreen or physical controller)
+ (void)loadDefaultProfileForDevice:(NSString *)deviceString;

// MARK: - Control Groups

/// Get all control group sections for the current controller
+ (NSArray<NSDictionary<NSString *, id> *> *)controlGroupSections;

/// Get the localized name for a section
+ (NSString *)localizedSectionName:(NSString *)name;

/// Get controls for a specific group
+ (NSArray<DOLControl *> *)controlsForGroupAtSection:(NSInteger)section row:(NSInteger)row;

/// Get numeric settings for a specific group
+ (NSArray<DOLNumericSetting *> *)numericSettingsForGroupAtSection:(NSInteger)section row:(NSInteger)row;

/// Get enabled state for a specific group
+ (BOOL)enabledForGroupAtSection:(NSInteger)section row:(NSInteger)row;

/// Set enabled state for a specific group
+ (void)setEnabled:(BOOL)enabled forGroupAtSection:(NSInteger)section row:(NSInteger)row;

// MARK: - Control Expression

/// Set expression for a control
+ (void)setExpression:(NSString *)expression forControlAtSection:(NSInteger)section row:(NSInteger)row controlIndex:(NSInteger)controlIndex;

/// Clear expression for a control
+ (void)clearExpressionForControlAtSection:(NSInteger)section row:(NSInteger)row controlIndex:(NSInteger)controlIndex;

// MARK: - Numeric Settings

/// Set double value for a numeric setting
+ (void)setDoubleValue:(double)value forSettingAtSection:(NSInteger)section row:(NSInteger)row settingIndex:(NSInteger)settingIndex;

/// Set bool value for a numeric setting
+ (void)setBoolValue:(BOOL)value forSettingAtSection:(NSInteger)section row:(NSInteger)row settingIndex:(NSInteger)settingIndex;

// MARK: - Extensions (Wiimote only)

/// Get current extension type
+ (DOLWiimoteExtension)currentExtension;

/// Get all available extension attachments
+ (NSArray<DOLExtensionAttachment *> *)extensionAttachments;

/// Set the current extension
+ (void)setExtension:(NSInteger)extensionIndex;

/// Get localized name for extension type
+ (NSString *)localizedExtensionName:(DOLWiimoteExtension)extension;

// MARK: - Profiles

/// Get all available profiles
+ (NSArray<DOLProfile *> *)profilesFilteringTouchscreen:(BOOL)filterTouchscreen;

/// Load a profile
+ (void)loadProfile:(DOLProfile *)profile;

/// Save current configuration as a profile
+ (BOOL)saveProfileWithName:(NSString *)name;

/// Delete a profile
+ (BOOL)deleteProfile:(DOLProfile *)profile;

// MARK: - Input Detection

/// Start input detection. Returns YES if started successfully.
+ (BOOL)startInputDetection;

/// Check if input detection is complete. Returns YES if complete.
+ (BOOL)isInputDetectionComplete;

/// Get the detected input expression. Returns nil if detection not complete or no input.
+ (nullable NSString *)detectedInputExpression;

/// Cancel input detection
+ (void)cancelInputDetection;

// MARK: - Input Display

/// Get all inputs for the current device
+ (NSArray<DOLInput *> *)inputsForCurrentDevice;

// MARK: - Utility

/// Get device filter type for current mapping configuration
+ (DOLDeviceFilterType)deviceFilterTypeForPort:(NSInteger)port mappingType:(DOLMappingType)type;

@end

NS_ASSUME_NONNULL_END
