// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "DOLMappingBridge.h"

#import <map>
#import <string>
#import <vector>
#import <chrono>

#import "Core/HW/GCPad.h"
#import "Core/HW/GCPadEmu.h"
#import "Core/HW/Wiimote.h"
#import "Core/HW/WiimoteEmu/Extension/Classic.h"
#import "Core/HW/WiimoteEmu/Extension/DrawsomeTablet.h"
#import "Core/HW/WiimoteEmu/Extension/Drums.h"
#import "Core/HW/WiimoteEmu/Extension/Guitar.h"
#import "Core/HW/WiimoteEmu/Extension/Nunchuk.h"
#import "Core/HW/WiimoteEmu/Extension/TaTaCon.h"
#import "Core/HW/WiimoteEmu/Extension/Turntable.h"
#import "Core/HW/WiimoteEmu/Extension/UDrawTablet.h"
#import "Core/HW/WiimoteEmu/WiimoteEmu.h"

#import "Common/FileSearch.h"
#import "Common/FileUtil.h"
#import "Common/IniFile.h"

#import "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#import "InputCommon/ControllerEmu/ControllerEmu.h"
#import "InputCommon/ControllerEmu/Setting/NumericSetting.h"
#import "InputCommon/ControllerInterface/ControllerInterface.h"
#import "InputCommon/ControllerInterface/MappingCommon.h"
#import "InputCommon/InputConfig.h"

#import "FoundationStringUtil.h"
#import "LocalizationUtil.h"

// MARK: - Model Implementations

@implementation DOLControlGroup
@end

@implementation DOLControl
@end

@implementation DOLNumericSetting
@end

@implementation DOLProfile
@end

@implementation DOLDevice
@end

@implementation DOLInput
@end

@implementation DOLExtensionAttachment
@end

// MARK: - Internal Structures

struct GroupInfo {
  std::string name;
  ControllerEmu::ControlGroup* controlGroup;
  bool isExtensionGroup = false;
};

struct SectionInfo {
  std::string headerName;
  std::string footerName;
  std::vector<GroupInfo> groups;
};

// MARK: - Static State

static InputConfig* s_config = nullptr;
static ControllerEmu::EmulatedController* s_controller = nullptr;
static DOLMappingType s_mappingType = DOLMappingTypePad;
static NSInteger s_mappingPort = 0;
static std::vector<SectionInfo> s_sections;
static std::unique_ptr<ciface::Core::InputDetector> s_inputDetector;
static NSLock* s_inputLock = [[NSLock alloc] init];

// MARK: - Helper Functions

static void PopulateSections() {
  s_sections.clear();
  
  switch (s_mappingType) {
    case DOLMappingTypePad: {
      s_sections.push_back({"General and Options", "", {
        {"Buttons", Pad::GetGroup((int)s_mappingPort, PadGroup::Buttons)},
        {"D-Pad", Pad::GetGroup((int)s_mappingPort, PadGroup::DPad)},
        {"Control Stick", Pad::GetGroup((int)s_mappingPort, PadGroup::MainStick)},
        {"C Stick", Pad::GetGroup((int)s_mappingPort, PadGroup::CStick)},
        {"Triggers", Pad::GetGroup((int)s_mappingPort, PadGroup::Triggers)},
        {"Rumble", Pad::GetGroup((int)s_mappingPort, PadGroup::Rumble)},
        {"Options", Pad::GetGroup((int)s_mappingPort, PadGroup::Options)}
      }});
      break;
    }
    case DOLMappingTypeWiimote: {
      ControllerEmu::ControlGroup* extension_group = Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Attachments);
      
      s_sections.push_back({"General and Options", "", {
        {"Buttons", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Buttons)},
        {"D-Pad", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::DPad)},
        {"Hotkeys", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Hotkeys)},
        {"Extension", extension_group, true},
        {"Rumble", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Rumble)},
        {"Options", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Options)}
      }});
      
      s_sections.push_back({"Motion Simulation", "", {
        {"Shake", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Shake)},
        {"Point", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Point)},
        {"Tilt", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Tilt)},
        {"Swing", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Swing)}
      }});
      
      std::string wiimoteMotionHelp = "WARNING: The controls under Accelerometer and Gyroscope are designed to "
                                      "interface directly with motion sensor hardware. They are not intended for "
                                      "mapping traditional buttons, triggers or axes. You might need to configure "
                                      "alternate input sources before using these controls.";
      
      s_sections.push_back({"Motion Input", wiimoteMotionHelp, {
        {"Point", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::IMUPoint)},
        {"Accelerometer", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::IMUAccelerometer)},
        {"Gyroscope", Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::IMUGyroscope)}
      }});
      
      ControllerEmu::Attachments* ce_extension = static_cast<ControllerEmu::Attachments*>(extension_group);
      WiimoteEmu::ExtensionNumber extension = static_cast<WiimoteEmu::ExtensionNumber>(ce_extension->GetSelectionSetting().GetValue());
      
      switch (extension) {
        case WiimoteEmu::ExtensionNumber::NUNCHUK: {
          s_sections.push_back({"Nunchuk", "", {
            {"Stick", Wiimote::GetNunchukGroup((int)s_mappingPort, WiimoteEmu::NunchukGroup::Stick)},
            {"Buttons", Wiimote::GetNunchukGroup((int)s_mappingPort, WiimoteEmu::NunchukGroup::Buttons)}
          }});
          
          s_sections.push_back({"Extension Motion Simulation", "", {
            {"Shake", Wiimote::GetNunchukGroup((int)s_mappingPort, WiimoteEmu::NunchukGroup::Shake)},
            {"Tilt", Wiimote::GetNunchukGroup((int)s_mappingPort, WiimoteEmu::NunchukGroup::Tilt)},
            {"Swing", Wiimote::GetNunchukGroup((int)s_mappingPort, WiimoteEmu::NunchukGroup::Swing)}
          }});
          
          std::string extensionMotionHelp = "WARNING: These controls are designed to interface directly with motion "
                                            "sensor hardware. They are not intended for mapping traditional buttons, triggers or "
                                            "axes. You might need to configure alternate input sources before using these controls.";
          
          s_sections.push_back({"Extension Motion Input", extensionMotionHelp, {
            {"Accelerometer", Wiimote::GetNunchukGroup((int)s_mappingPort, WiimoteEmu::NunchukGroup::IMUAccelerometer)}
          }});
          
          break;
        }
        case WiimoteEmu::ExtensionNumber::CLASSIC:
          s_sections.push_back({"Classic Controller", "", {
            {"Buttons", Wiimote::GetClassicGroup((int)s_mappingPort, WiimoteEmu::ClassicGroup::Buttons)},
            {"D-Pad", Wiimote::GetClassicGroup((int)s_mappingPort, WiimoteEmu::ClassicGroup::DPad)},
            {"Left Stick", Wiimote::GetClassicGroup((int)s_mappingPort, WiimoteEmu::ClassicGroup::LeftStick)},
            {"Right Stick", Wiimote::GetClassicGroup((int)s_mappingPort, WiimoteEmu::ClassicGroup::RightStick)},
            {"Triggers", Wiimote::GetClassicGroup((int)s_mappingPort, WiimoteEmu::ClassicGroup::Triggers)}
          }});
          break;
        case WiimoteEmu::ExtensionNumber::GUITAR:
          s_sections.push_back({"Guitar", "", {
            {"Stick", Wiimote::GetGuitarGroup((int)s_mappingPort, WiimoteEmu::GuitarGroup::Stick)},
            {"Strum", Wiimote::GetGuitarGroup((int)s_mappingPort, WiimoteEmu::GuitarGroup::Strum)},
            {"Frets", Wiimote::GetGuitarGroup((int)s_mappingPort, WiimoteEmu::GuitarGroup::Frets)},
            {"Buttons", Wiimote::GetGuitarGroup((int)s_mappingPort, WiimoteEmu::GuitarGroup::Buttons)},
            {"Whammy", Wiimote::GetGuitarGroup((int)s_mappingPort, WiimoteEmu::GuitarGroup::Whammy)},
            {"Slider Bar", Wiimote::GetGuitarGroup((int)s_mappingPort, WiimoteEmu::GuitarGroup::SliderBar)},
          }});
          break;
        case WiimoteEmu::ExtensionNumber::DRUMS:
          s_sections.push_back({"Drum Kit", "", {
            {"Stick", Wiimote::GetDrumsGroup((int)s_mappingPort, WiimoteEmu::DrumsGroup::Stick)},
            {"Pads", Wiimote::GetDrumsGroup((int)s_mappingPort, WiimoteEmu::DrumsGroup::Pads)},
            {"Buttons", Wiimote::GetDrumsGroup((int)s_mappingPort, WiimoteEmu::DrumsGroup::Buttons)}
          }});
          break;
        case WiimoteEmu::ExtensionNumber::TURNTABLE:
          s_sections.push_back({"DJ Turntable", "", {
            {"Stick", Wiimote::GetTurntableGroup((int)s_mappingPort, WiimoteEmu::TurntableGroup::Stick)},
            {"Buttons", Wiimote::GetTurntableGroup((int)s_mappingPort, WiimoteEmu::TurntableGroup::Buttons)},
            {"Effect", Wiimote::GetTurntableGroup((int)s_mappingPort, WiimoteEmu::TurntableGroup::EffectDial)},
            {"Left Table", Wiimote::GetTurntableGroup((int)s_mappingPort, WiimoteEmu::TurntableGroup::LeftTable)},
            {"Right Table", Wiimote::GetTurntableGroup((int)s_mappingPort, WiimoteEmu::TurntableGroup::RightTable)},
            {"Crossfade", Wiimote::GetTurntableGroup((int)s_mappingPort, WiimoteEmu::TurntableGroup::Crossfade)}
          }});
          break;
        case WiimoteEmu::ExtensionNumber::UDRAW_TABLET:
          s_sections.push_back({"uDraw GameTablet", "", {
            {"Buttons", Wiimote::GetUDrawTabletGroup((int)s_mappingPort, WiimoteEmu::UDrawTabletGroup::Buttons)},
            {"Stylus", Wiimote::GetUDrawTabletGroup((int)s_mappingPort, WiimoteEmu::UDrawTabletGroup::Stylus)},
            {"Touch", Wiimote::GetUDrawTabletGroup((int)s_mappingPort, WiimoteEmu::UDrawTabletGroup::Touch)}
          }});
          break;
        case WiimoteEmu::ExtensionNumber::DRAWSOME_TABLET:
          s_sections.push_back({"Drawsome Tablet", "", {
            {"Stylus", Wiimote::GetDrawsomeTabletGroup((int)s_mappingPort, WiimoteEmu::DrawsomeTabletGroup::Stylus)},
            {"Touch", Wiimote::GetDrawsomeTabletGroup((int)s_mappingPort, WiimoteEmu::DrawsomeTabletGroup::Touch)}
          }});
          break;
        case WiimoteEmu::ExtensionNumber::TATACON:
          s_sections.push_back({"Taiko Drum", "", {
            {"Center", Wiimote::GetTaTaConGroup((int)s_mappingPort, WiimoteEmu::TaTaConGroup::Center)},
            {"Rim", Wiimote::GetTaTaConGroup((int)s_mappingPort, WiimoteEmu::TaTaConGroup::Rim)}
          }});
          break;
        default:
          break;
      }
      
      break;
    }
  }
}

static ControllerEmu::ControlGroup* GetControlGroup(NSInteger section, NSInteger row) {
  if (section < 0 || section >= (NSInteger)s_sections.size()) {
    return nullptr;
  }
  if (row < 0 || row >= (NSInteger)s_sections[section].groups.size()) {
    return nullptr;
  }
  return s_sections[section].groups[row].controlGroup;
}

// MARK: - DOLMappingBridge Implementation

@implementation DOLMappingBridge

+ (void)initializeForType:(DOLMappingType)type port:(NSInteger)port {
  s_mappingType = type;
  s_mappingPort = port;
  
  if (type == DOLMappingTypePad) {
    s_config = Pad::GetConfig();
  } else if (type == DOLMappingTypeWiimote) {
    s_config = Wiimote::GetConfig();
  }
  
  s_controller = s_config->GetController((int)port);
  
  PopulateSections();
}

+ (void)saveConfig {
  if (s_config) {
    s_config->SaveConfig();
  }
}

+ (void)refreshDevices {
  // Disabled: RefreshDevices() when opening controller/mapping UI causes crashes on iOS.
  // Device list uses existing ControllerInterface state instead.
}

// MARK: - Device Management

+ (NSString *)defaultDevice {
  if (!s_controller) return @"";
  
  const auto deviceString = s_controller->GetDefaultDevice().ToString();
  if (deviceString.empty()) {
    return @"";
  }
  return CppToFoundationString(deviceString);
}

+ (void)setDefaultDevice:(NSString *)deviceString {
  if (!s_controller) return;
  
  std::string device = FoundationToCppString(deviceString);
  s_controller->SetDefaultDevice(device);
  s_controller->UpdateReferences(g_controller_interface);
}

+ (NSArray<DOLDevice *> *)devicesWithFilter:(DOLDeviceFilterType)filterType {
  NSMutableArray<DOLDevice *>* result = [NSMutableArray array];
  
  // Do not call RefreshDevices() here; it can crash when opening controller settings.
  
  const std::string defaultDevice = s_controller ? s_controller->GetDefaultDevice().ToString() : "";
  bool foundDefault = false;
  
  for (const auto& name : g_controller_interface.GetAllDeviceStrings()) {
    if (filterType != DOLDeviceFilterTypeNone) {
      ciface::Core::DeviceQualifier qualifier;
      qualifier.FromString(name);
      
      if (qualifier.source == "iOS" && qualifier.name == "Touchscreen") {
        if (filterType == DOLDeviceFilterTypePhysicalOnly) {
          continue;
        }
        if ((filterType == DOLDeviceFilterTypeTouchscreenExceptPad && qualifier.cid != 0)
            || (filterType == DOLDeviceFilterTypeTouchscreenExceptWii && qualifier.cid != 4)
            || filterType == DOLDeviceFilterTypeTouchscreenAll) {
          continue;
        }
      }
    }
    
    DOLDevice* device = [[DOLDevice alloc] init];
    device.name = CppToFoundationString(name);
    device.displayName = device.name;
    device.isDisconnected = NO;
    
    if (name == defaultDevice) {
      foundDefault = true;
    }
    
    [result addObject:device];
  }
  
  // Add disconnected default device if not found
  if (!defaultDevice.empty() && !foundDefault) {
    DOLDevice* device = [[DOLDevice alloc] init];
    device.name = CppToFoundationString(defaultDevice);
    device.displayName = [NSString stringWithFormat:@"[%@] %@", DOLCoreLocalizedString(@"disconnected"), device.name];
    device.isDisconnected = YES;
    [result addObject:device];
  }
  
  return result;
}

+ (BOOL)isTouchscreenDevice:(NSString *)deviceString {
  ciface::Core::DeviceQualifier qualifier;
  qualifier.FromString(FoundationToCppString(deviceString));
  return qualifier.source == "iOS";
}

+ (BOOL)isMFiPhysicalController:(NSString *)deviceString {
  ciface::Core::DeviceQualifier qualifier;
  qualifier.FromString(FoundationToCppString(deviceString));
  return qualifier.source == "MFi" && qualifier.name != "Keyboard";
}

+ (NSString *)touchscreenDeviceStringForPort0WithMappingType:(DOLMappingType)type {
  if (type == DOLMappingTypePad) {
    return @"iOS/0/Touchscreen";
  }
  return @"iOS/4/Touchscreen";
}

+ (void)loadDefaultProfileForDevice:(NSString *)deviceString {
  if (!s_controller || !s_config) return;
  
  std::string iniName;
  
  if ([self isTouchscreenDevice:deviceString]) {
    iniName = "Touchscreen";
  } else if ([self isMFiPhysicalController:deviceString]) {
    iniName = "Physical Controller";
  } else {
    return;
  }
  
  const std::string profilePath = s_config->GetSysProfileDirectoryPath() + iniName + ".ini";
  
  Common::IniFile iniFile;
  iniFile.Load(profilePath);
  
  std::string device = FoundationToCppString(deviceString);
  s_controller->LoadConfig(iniFile.GetOrCreateSection("Profile"));
  s_controller->SetDefaultDevice(device);
  s_controller->UpdateReferences(g_controller_interface);
}

// MARK: - Control Groups

+ (NSArray<NSDictionary<NSString *, id> *> *)controlGroupSections {
  NSMutableArray* result = [NSMutableArray array];
  
  for (size_t i = 0; i < s_sections.size(); i++) {
    const auto& section = s_sections[i];
    NSMutableArray<DOLControlGroup *>* groups = [NSMutableArray array];
    
    for (size_t j = 0; j < section.groups.size(); j++) {
      const auto& group = section.groups[j];
      
      DOLControlGroup* controlGroup = [[DOLControlGroup alloc] init];
      controlGroup.name = CppToFoundationString(group.name);
      controlGroup.uiName = DOLCoreLocalizedString(controlGroup.name);
      controlGroup.groupIndex = j;
      controlGroup.isExtensionGroup = group.isExtensionGroup;
      
      if (group.controlGroup) {
        controlGroup.hasEnabledSetting = group.controlGroup->HasEnabledSetting();
        controlGroup.isEnabled = !controlGroup.hasEnabledSetting || group.controlGroup->enabled_setting->GetValue();
      }
      
      [groups addObject:controlGroup];
    }
    
    NSDictionary* sectionDict = @{
      @"headerName": CppToFoundationString(section.headerName),
      @"footerName": CppToFoundationString(section.footerName),
      @"groups": groups
    };
    
    [result addObject:sectionDict];
  }
  
  return result;
}

+ (NSString *)localizedSectionName:(NSString *)name {
  return DOLCoreLocalizedString(name);
}

+ (NSArray<DOLControl *> *)controlsForGroupAtSection:(NSInteger)section row:(NSInteger)row {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group) return @[];
  
  NSMutableArray<DOLControl *>* result = [NSMutableArray array];
  
  const auto lock = ControllerEmu::EmulatedController::GetStateLock();
  
  for (size_t i = 0; i < group->controls.size(); i++) {
    const auto& control = group->controls[i];
    
    DOLControl* dolControl = [[DOLControl alloc] init];
    dolControl.name = CppToFoundationString(control->ui_name);
    dolControl.shouldTranslate = control->translate == ControllerEmu::Translatability::Translate;
    dolControl.uiName = dolControl.shouldTranslate ? DOLCoreLocalizedString(dolControl.name) : dolControl.name;
    dolControl.expression = CppToFoundationString(control->control_ref->GetExpression());
    dolControl.controlIndex = i;
    
    [result addObject:dolControl];
  }
  
  return result;
}

+ (NSArray<DOLNumericSetting *> *)numericSettingsForGroupAtSection:(NSInteger)section row:(NSInteger)row {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group) return @[];
  
  NSMutableArray<DOLNumericSetting *>* result = [NSMutableArray array];
  
  for (size_t i = 0; i < group->numeric_settings.size(); i++) {
    const auto& setting = group->numeric_settings[i];
    
    DOLNumericSetting* dolSetting = [[DOLNumericSetting alloc] init];
    dolSetting.name = CToFoundationString(setting->GetUIName());
    dolSetting.uiName = DOLCoreLocalizedString(dolSetting.name);
    dolSetting.settingIndex = i;
    
    if (setting->GetUIDescription()) {
      dolSetting.uiDescription = DOLCoreLocalizedString(CToFoundationString(setting->GetUIDescription()));
    }
    
    if (setting->GetUISuffix()) {
      dolSetting.uiSuffix = DOLCoreLocalizedString(CToFoundationString(setting->GetUISuffix()));
    }
    
    switch (setting->GetType()) {
      case ControllerEmu::SettingType::Double: {
        auto doubleSetting = static_cast<ControllerEmu::NumericSetting<double>*>(setting.get());
        dolSetting.settingType = DOLSettingTypeDouble;
        dolSetting.doubleValue = doubleSetting->GetValue();
        dolSetting.minValue = doubleSetting->GetMinValue();
        dolSetting.maxValue = doubleSetting->GetMaxValue();
        break;
      }
      case ControllerEmu::SettingType::Bool: {
        auto boolSetting = static_cast<ControllerEmu::NumericSetting<bool>*>(setting.get());
        dolSetting.settingType = DOLSettingTypeBool;
        dolSetting.boolValue = boolSetting->GetValue();
        break;
      }
      default:
        continue;
    }
    
    [result addObject:dolSetting];
  }
  
  return result;
}

+ (BOOL)enabledForGroupAtSection:(NSInteger)section row:(NSInteger)row {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group) return YES;
  
  if (!group->HasEnabledSetting()) return YES;
  return group->enabled_setting->GetValue();
}

+ (void)setEnabled:(BOOL)enabled forGroupAtSection:(NSInteger)section row:(NSInteger)row {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group || !group->HasEnabledSetting()) return;
  
  group->enabled.SetValue(enabled);
}

// MARK: - Control Expression

+ (void)setExpression:(NSString *)expression forControlAtSection:(NSInteger)section row:(NSInteger)row controlIndex:(NSInteger)controlIndex {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group || controlIndex < 0 || controlIndex >= (NSInteger)group->controls.size()) return;
  
  auto& controlRef = group->controls[controlIndex]->control_ref;
  controlRef->SetExpression(FoundationToCppString(expression));
  s_controller->UpdateSingleControlReference(g_controller_interface, controlRef.get());
}

+ (void)clearExpressionForControlAtSection:(NSInteger)section row:(NSInteger)row controlIndex:(NSInteger)controlIndex {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group || controlIndex < 0 || controlIndex >= (NSInteger)group->controls.size()) return;
  
  auto& controlRef = group->controls[controlIndex]->control_ref;
  controlRef->range = 1.0;
  controlRef->SetExpression("");
  s_controller->UpdateSingleControlReference(g_controller_interface, controlRef.get());
}

// MARK: - Numeric Settings

+ (void)setDoubleValue:(double)value forSettingAtSection:(NSInteger)section row:(NSInteger)row settingIndex:(NSInteger)settingIndex {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group || settingIndex < 0 || settingIndex >= (NSInteger)group->numeric_settings.size()) return;
  
  auto& setting = group->numeric_settings[settingIndex];
  if (setting->GetType() != ControllerEmu::SettingType::Double) return;
  
  auto doubleSetting = static_cast<ControllerEmu::NumericSetting<double>*>(setting.get());
  
  double minValue = doubleSetting->GetMinValue();
  double maxValue = doubleSetting->GetMaxValue();
  
  if (value < minValue) value = minValue;
  if (value > maxValue) value = maxValue;
  
  doubleSetting->SetValue(value);
}

+ (void)setBoolValue:(BOOL)value forSettingAtSection:(NSInteger)section row:(NSInteger)row settingIndex:(NSInteger)settingIndex {
  ControllerEmu::ControlGroup* group = GetControlGroup(section, row);
  if (!group || settingIndex < 0 || settingIndex >= (NSInteger)group->numeric_settings.size()) return;
  
  auto& setting = group->numeric_settings[settingIndex];
  if (setting->GetType() != ControllerEmu::SettingType::Bool) return;
  
  auto boolSetting = static_cast<ControllerEmu::NumericSetting<bool>*>(setting.get());
  boolSetting->SetValue(value);
}

// MARK: - Extensions

+ (DOLWiimoteExtension)currentExtension {
  if (s_mappingType != DOLMappingTypeWiimote) return DOLWiimoteExtensionNone;
  
  ControllerEmu::ControlGroup* extensionGroup = Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Attachments);
  auto attachments = static_cast<ControllerEmu::Attachments*>(extensionGroup);
  
  return (DOLWiimoteExtension)attachments->GetSelectedAttachment();
}

+ (NSArray<DOLExtensionAttachment *> *)extensionAttachments {
  if (s_mappingType != DOLMappingTypeWiimote) return @[];
  
  ControllerEmu::ControlGroup* extensionGroup = Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Attachments);
  auto attachments = static_cast<ControllerEmu::Attachments*>(extensionGroup);
  
  NSMutableArray<DOLExtensionAttachment *>* result = [NSMutableArray array];
  
  const auto& attachmentList = attachments->GetAttachmentList();
  for (size_t i = 0; i < attachmentList.size(); i++) {
    const auto& attachment = attachmentList[i];
    
    DOLExtensionAttachment* dolAttachment = [[DOLExtensionAttachment alloc] init];
    dolAttachment.name = CppToFoundationString(attachment->GetName());
    dolAttachment.displayName = DOLCoreLocalizedString(CppToFoundationString(attachment->GetDisplayName()));
    dolAttachment.index = i;
    
    [result addObject:dolAttachment];
  }
  
  return result;
}

+ (void)setExtension:(NSInteger)extensionIndex {
  if (s_mappingType != DOLMappingTypeWiimote) return;
  
  ControllerEmu::ControlGroup* extensionGroup = Wiimote::GetWiimoteGroup((int)s_mappingPort, WiimoteEmu::WiimoteGroup::Attachments);
  auto attachments = static_cast<ControllerEmu::Attachments*>(extensionGroup);
  
  attachments->SetSelectedAttachment((u32)extensionIndex);
  
  // Re-populate sections to show extension-specific groups
  PopulateSections();
}

+ (NSString *)localizedExtensionName:(DOLWiimoteExtension)extension {
  NSString* localizable;
  switch (extension) {
    case DOLWiimoteExtensionNone:
      localizable = @"None";
      break;
    case DOLWiimoteExtensionNunchuk:
      localizable = @"Nunchuk";
      break;
    case DOLWiimoteExtensionClassic:
      localizable = @"Classic Controller";
      break;
    case DOLWiimoteExtensionGuitar:
      localizable = @"Guitar";
      break;
    case DOLWiimoteExtensionDrums:
      localizable = @"Drum Kit";
      break;
    case DOLWiimoteExtensionTurntable:
      localizable = @"DJ Turntable";
      break;
    case DOLWiimoteExtensionUDrawTablet:
      localizable = @"uDraw GameTablet";
      break;
    case DOLWiimoteExtensionDrawsomeTablet:
      localizable = @"Drawsome Tablet";
      break;
    case DOLWiimoteExtensionTaTaCon:
      localizable = @"Taiko Drum";
      break;
    default:
      localizable = @"Unknown";
      break;
  }
  
  return DOLCoreLocalizedString(localizable);
}

// MARK: - Profiles

+ (NSArray<DOLProfile *> *)profilesFilteringTouchscreen:(BOOL)filterTouchscreen {
  if (!s_config) return @[];
  
  NSMutableArray<DOLProfile *>* result = [NSMutableArray array];
  
  // User profiles
  for (const auto& filename : Common::DoFileSearch({s_config->GetUserProfileDirectoryPath()}, {".ini"})) {
    std::string basename;
    SplitPath(filename, nullptr, &basename, nullptr);
    
    if (!basename.empty()) {
      DOLProfile* profile = [[DOLProfile alloc] init];
      profile.name = CppToFoundationString(basename);
      profile.path = CppToFoundationString(filename);
      profile.isStock = NO;
      [result addObject:profile];
    }
  }
  
  // System profiles
  for (const auto& filename : Common::DoFileSearch({s_config->GetSysProfileDirectoryPath()}, {".ini"})) {
    std::string basename;
    SplitPath(filename, nullptr, &basename, nullptr);
    
    // Skip Wii Remote with MotionPlus Pointing (not supported on iOS)
    if (basename == "Wii Remote with MotionPlus Pointing") {
      continue;
    }
    
    // Skip Touchscreen profile if filtering
    if (basename == "Touchscreen" && filterTouchscreen) {
      continue;
    }
    
    if (!basename.empty()) {
      DOLProfile* profile = [[DOLProfile alloc] init];
      profile.name = CppToFoundationString(basename);
      profile.path = CppToFoundationString(filename);
      profile.isStock = YES;
      [result addObject:profile];
    }
  }
  
  return result;
}

+ (void)loadProfile:(DOLProfile *)profile {
  if (!s_controller) return;
  
  Common::IniFile ini;
  ini.Load(FoundationToCppString(profile.path));
  
  s_controller->LoadConfig(ini.GetOrCreateSection("Profile"));
  s_controller->UpdateReferences(g_controller_interface);
  
  PopulateSections();
}

+ (BOOL)saveProfileWithName:(NSString *)name {
  if (!s_config || !s_controller || name.length == 0) return NO;
  
  const std::string profilePath = s_config->GetUserProfileDirectoryPath() + FoundationToCppString(name) + ".ini";
  
  File::CreateFullPath(profilePath);
  
  Common::IniFile ini;
  s_controller->SaveConfig(ini.GetOrCreateSection("Profile"));
  
  return ini.Save(profilePath);
}

+ (BOOL)deleteProfile:(DOLProfile *)profile {
  if (profile.isStock) return NO;
  return File::Delete(FoundationToCppString(profile.path));
}

// MARK: - Input Detection

+ (BOOL)startInputDetection {
  [s_inputLock lock];
  
  if (!s_controller) {
    [s_inputLock unlock];
    return NO;
  }
  
  s_inputDetector = std::make_unique<ciface::Core::InputDetector>();
  
  std::vector<std::string> devices = {s_controller->GetDefaultDevice().ToString()};
  s_inputDetector->Start(g_controller_interface, devices);
  
  [s_inputLock unlock];
  return YES;
}

+ (BOOL)isInputDetectionComplete {
  [s_inputLock lock];
  
  if (!s_inputDetector) {
    [s_inputLock unlock];
    return YES;
  }
  
  constexpr auto initial_time = std::chrono::seconds(3);
  constexpr auto confirmation_time = std::chrono::milliseconds(0);
  constexpr auto maximum_time = std::chrono::seconds(5);
  
  s_inputDetector->Update(initial_time, confirmation_time, maximum_time);
  
  bool complete = s_inputDetector->IsComplete();
  
  [s_inputLock unlock];
  return complete;
}

+ (nullable NSString *)detectedInputExpression {
  [s_inputLock lock];
  
  if (!s_inputDetector || !s_controller) {
    [s_inputLock unlock];
    return nil;
  }
  
  auto results = s_inputDetector->TakeResults();
  
  if (ciface::MappingCommon::ContainsCompleteDetection(results)) {
    std::string expression = BuildExpression(results, s_controller->GetDefaultDevice(), ciface::MappingCommon::Quote::On);
    
    s_inputDetector.reset();
    [s_inputLock unlock];
    
    if (!expression.empty()) {
      return CppToFoundationString(expression);
    }
  }
  
  s_inputDetector.reset();
  [s_inputLock unlock];
  return nil;
}

+ (void)cancelInputDetection {
  [s_inputLock lock];
  s_inputDetector.reset();
  [s_inputLock unlock];
}

// MARK: - Input Display

+ (NSArray<DOLInput *> *)inputsForCurrentDevice {
  if (!s_controller) return @[];
  
  ciface::Core::DeviceQualifier qualifier;
  qualifier.FromString(s_controller->GetDefaultDevice().ToString());
  
  auto device = g_controller_interface.FindDevice(qualifier);
  if (!device) return @[];
  
  NSMutableArray<DOLInput *>* result = [NSMutableArray array];
  
  for (const auto& input : device->Inputs()) {
    DOLInput* dolInput = [[DOLInput alloc] init];
    dolInput.name = CppToFoundationString(input->GetName());
    dolInput.value = input->GetState();
    [result addObject:dolInput];
  }
  
  return result;
}

// MARK: - Utility

+ (DOLDeviceFilterType)deviceFilterTypeForPort:(NSInteger)port mappingType:(DOLMappingType)type {
  if (type == DOLMappingTypePad && port == 0) {
    return DOLDeviceFilterTypeTouchscreenExceptPad;
  } else if (type == DOLMappingTypeWiimote && port == 0) {
    return DOLDeviceFilterTypeTouchscreenExceptWii;
  } else {
    return DOLDeviceFilterTypeTouchscreenAll;
  }
}

@end
