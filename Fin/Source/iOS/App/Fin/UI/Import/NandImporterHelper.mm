// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "NandImporterHelper.h"

#import "DiscIO/NANDImporter.h"
#import "FoundationStringUtil.h"

#include "Common/MsgHandler.h"

@implementation NandImporterHelper

+ (void)importNandAtPath:(NSString*)path completion:(void (^)(void))completion {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    DiscIO::NANDImporter().ImportNANDBin(
        FoundationToCppString(path),
        [] {},
        [] {
          PanicAlertFmtT("The decryption keys need to be appended to the NAND backup file.");
          return std::string("");
        });
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion) completion();
    });
  });
}

@end
