// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "EmulationBootParameter.h"

#import "Core/Boot/Boot.h"
#import "Core/CommonTitles.h"

#import "FoundationStringUtil.h"

@implementation EmulationBootParameter

- (std::unique_ptr<BootParameters>) generateDolphinBootParameter {
  std::unique_ptr<BootParameters> boot;
  
  if (self.bootType == EmulationBootTypeFile) {
    std::vector<std::string> paths = {FoundationToCppString(self.path)};
    
    if (self.secondPath != nil) {
      paths.push_back(FoundationToCppString(self.secondPath));
    }
    
    BootSessionData session_data;
    if (self.savestatePath.length > 0) {
      session_data = BootSessionData(std::optional<std::string>(FoundationToCppString(self.savestatePath)),
                                     DeleteSavestateAfterBoot::No);
    }
    boot = BootParameters::GenerateFromFile(paths, std::move(session_data));
  } else if (self.bootType == EmulationBootTypeSystemMenu) {
    boot = std::make_unique<BootParameters>(BootParameters::NANDTitle{Titles::SYSTEM_MENU});
  } else {
    boot = std::make_unique<BootParameters>(BootParameters::IPL{self.iplRegion});
  }
  
  return boot;
}

@end
